import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' show CloseHandle, OpenProcess, PROCESS_QUERY_INFORMATION, PROCESS_VM_READ;

/// WDDM Display Adapter discovered via DXGI (`dxgi.dll`).
class GpuAdapterInfo {
  final int luid;
  final String name;
  final int vendorId;
  final int dedicatedVramBytes;
  final int sharedSystemBytes;
  final bool isSoftware;

  const GpuAdapterInfo({
    required this.luid,
    required this.name,
    required this.vendorId,
    required this.dedicatedVramBytes,
    required this.sharedSystemBytes,
    this.isSoftware = false,
  });

  String get vendorName {
    switch (vendorId) {
      case 0x10DE:
        return 'NVIDIA';
      case 0x1002:
        return 'AMD';
      case 0x8086:
        return 'Intel';
      case 0x1414:
        return 'Microsoft';
      case 0x5143:
        return 'Qualcomm';
      default:
        return '0x${vendorId.toRadixString(16).toUpperCase()}';
    }
  }

  /// DXGI-capacity heuristic matching gputaskman: Intel iGPU has <= 512 MiB
  /// dedicated VRAM and more shared system memory.
  bool get isIntegratedIntel =>
      vendorId == 0x8086 &&
      dedicatedVramBytes <= (512 * 1024 * 1024) &&
      sharedSystemBytes > dedicatedVramBytes;

  String get formattedLuid {
    final hi = ((luid >> 32) & 0xFFFFFFFF).toRadixString(16);
    final lo = (luid & 0xFFFFFFFF).toRadixString(16);
    return '0x${hi}_0x$lo';
  }
}

/// GGUF model metadata and memory breakdown (weights vs. KV cache vs. compute).
class GgufModelInfo {
  final String fileName;
  final String architecture;
  final String quantization;
  final int fileSizeBytes;
  final int estimatedWeightsBytes;
  final int estimatedKvCacheBytes;
  final int estimatedComputeBytes;
  final String evidence;

  const GgufModelInfo({
    required this.fileName,
    required this.architecture,
    required this.quantization,
    required this.fileSizeBytes,
    required this.estimatedWeightsBytes,
    required this.estimatedKvCacheBytes,
    required this.estimatedComputeBytes,
    required this.evidence,
  });
}

/// Per-process WDDM GPU memory and engine counters plus runtime/AI attribution.
class ProcessGpuTelemetry {
  final int pid;
  final int adapterLuid;
  final int dedicatedBytes;
  final int sharedBytes;
  final int committedBytes;
  final Map<String, double> engines;
  final List<String> runtimes;
  final String category;
  final GgufModelInfo? modelInfo;

  const ProcessGpuTelemetry({
    required this.pid,
    required this.adapterLuid,
    required this.dedicatedBytes,
    required this.sharedBytes,
    required this.committedBytes,
    this.engines = const {},
    this.runtimes = const [],
    this.category = '',
    this.modelInfo,
  });

  /// Non-residency estimate: max(Total Committed - Local - Non Local, 0).
  int get pagedBytes => max(0, committedBytes - dedicatedBytes - sharedBytes);

  /// Task Manager semantics: busiest engine utilization wins.
  double get gpuPercent {
    if (engines.isEmpty) return 0.0;
    double best = 0.0;
    for (final v in engines.values) {
      if (v > best) best = v;
    }
    return best.clamp(0.0, 100.0);
  }
}

/// Adapter-wide GPU telemetry aggregated from WDDM PDH counters.
class AdapterGpuTelemetry {
  final GpuAdapterInfo adapter;
  final int dedicatedUsedBytes;
  final int sharedUsedBytes;
  final int attributedVramBytes;
  final double gpuUtilizationPercent;
  final Map<String, double> engineUtilization;

  const AdapterGpuTelemetry({
    required this.adapter,
    required this.dedicatedUsedBytes,
    required this.sharedUsedBytes,
    required this.attributedVramBytes,
    required this.gpuUtilizationPercent,
    this.engineUtilization = const {},
  });

  int get unattributedVramBytes => max(0, dedicatedUsedBytes - attributedVramBytes);

  double get vramUsagePercent => adapter.dedicatedVramBytes > 0
      ? ((dedicatedUsedBytes / adapter.dedicatedVramBytes) * 100.0).clamp(0.0, 100.0)
      : 0.0;
}

/// Complete GPU snapshot across all adapters and processes for the selected adapter.
class GpuSnapshot {
  final List<AdapterGpuTelemetry> adapters;
  final Map<int, ProcessGpuTelemetry> processMap;

  const GpuSnapshot({
    this.adapters = const [],
    this.processMap = const {},
  });
}

/// Per-process delta between two captured GPU snapshots (`gputaskman/diff.py`).
class ProcessGpuDiff {
  final int? pidBefore;
  final int? pidAfter;
  final String name;
  final String category;
  final String status; // 'paired' | 'new' | 'gone'
  final int dedicatedBefore;
  final int dedicatedAfter;
  final int sharedBefore;
  final int sharedAfter;
  final int committedBefore;
  final int committedAfter;

  const ProcessGpuDiff({
    required this.pidBefore,
    required this.pidAfter,
    required this.name,
    required this.category,
    required this.status,
    required this.dedicatedBefore,
    required this.dedicatedAfter,
    required this.sharedBefore,
    required this.sharedAfter,
    required this.committedBefore,
    required this.committedAfter,
  });

  int get dedicatedDelta => dedicatedAfter - dedicatedBefore;
  int get sharedDelta => sharedAfter - sharedBefore;
  int get committedDelta => committedAfter - committedBefore;
  int get pagedBefore => max(0, committedBefore - dedicatedBefore - sharedBefore);
  int get pagedAfter => max(0, committedAfter - dedicatedAfter - sharedAfter);
  int get pagedDelta => pagedAfter - pagedBefore;

  int get maxAbsDelta => [
        dedicatedDelta.abs(),
        sharedDelta.abs(),
        committedDelta.abs(),
        pagedDelta.abs(),
      ].reduce(max);
}

/// Adapter- and process-level delta between two GPU snapshots (`gputaskman/diff.py`).
class GpuSnapshotDiff {
  final String adapterName;
  final int dedicatedDelta;
  final int sharedDelta;
  final int attributedDelta;
  final int unattributedDelta;
  final List<ProcessGpuDiff> processes;

  const GpuSnapshotDiff({
    required this.adapterName,
    required this.dedicatedDelta,
    required this.sharedDelta,
    required this.attributedDelta,
    required this.unattributedDelta,
    required this.processes,
  });

  List<ProcessGpuDiff> significantProcesses([int thresholdBytes = 16 * 1024 * 1024]) =>
      processes.where((p) => p.maxAbsDelta >= thresholdBytes).toList();
}

// ---------------------------------------------------------------------------
// Native Win32 Structs for PDH & DXGI
// ---------------------------------------------------------------------------

final class PdhFmtCounterValueItemW extends Struct {
  external Pointer<Utf16> szName;
  @Uint32()
  external int cStatus;
  @Uint32()
  external int reserved;
  @Double()
  external double doubleValue;
}

final class _DxgiGuid extends Struct {
  @Uint32()
  external int d1;
  @Uint16()
  external int d2;
  @Uint16()
  external int d3;
  @Array(8)
  external Array<Uint8> d4;
}

final class _DxgiAdapterDesc1 extends Struct {
  @Array(128)
  external Array<Uint16> description;
  @Uint32()
  external int vendorId;
  @Uint32()
  external int deviceId;
  @Uint32()
  external int subSysId;
  @Uint32()
  external int revision;
  @UintPtr()
  external int dedicatedVideoMemory;
  @UintPtr()
  external int dedicatedSystemMemory;
  @UintPtr()
  external int sharedSystemMemory;
  @Uint32()
  external int luidLowPart;
  @Int32()
  external int luidHighPart;
  @Uint32()
  external int flags;
}

// ---------------------------------------------------------------------------
// GpuTaskManService
// ---------------------------------------------------------------------------

class GpuTaskManService {
  static const int _pdhFmtDouble = 0x00000200;
  static const int _pdhFmtNocap100 = 0x00008000;
  static const int _pdhMoreData = 0x800007D2;
  static const int _dxgiErrorNotFound = 0x887A0002;
  static const int _listModulesAll = 0x03;

  static final RegExp _luidPrefixRe = RegExp(r'^luid_0x([0-9a-fA-F]+)_0x([0-9a-fA-F]+)_phys_\d+$');
  static final RegExp _procRe = RegExp(r'^pid_(\d+)_luid_0x([0-9a-fA-F]+)_0x([0-9a-fA-F]+)_phys_\d+');
  static final RegExp _engineRe = RegExp(
    r'^pid_(\d+)_luid_0x([0-9a-fA-F]+)_0x([0-9a-fA-F]+)_phys_(\d+)_eng_(\d+)_engtype_(.*)$',
  );

  // Runtime DLL patterns ordered by display specificity (matching gputaskman/procinfo.py)
  static final List<MapEntry<String, List<RegExp>>> _runtimePatterns = [];
  static List<MapEntry<String, List<RegExp>>> _getRuntimePatterns() {
    if (_runtimePatterns.isNotEmpty) return _runtimePatterns;
    RegExp glob(String p) {
      final escaped = RegExp.escape(p).replaceAll(r'\*', '.*');
      return RegExp('^$escaped\$', caseSensitive: false);
    }

    final specs = <MapEntry<String, List<String>>>[
      const MapEntry('llama.cpp', ['llama.dll', 'libllama*.dll', 'llama-*.dll', 'llm_engine*']),
      const MapEntry('whisper.cpp', ['whisper*.dll']),
      const MapEntry('ggml', ['ggml*.dll']),
      const MapEntry('PyTorch', ['torch_cuda*.dll', 'torch_cpu.dll']),
      const MapEntry('TensorRT', ['nvinfer*.dll']),
      const MapEntry('ONNX RT', ['onnxruntime*.dll']),
      const MapEntry('DirectML', ['directml.dll']),
      const MapEntry('HIP', ['amdhip64.dll', 'amdhip64_*.dll']),
      const MapEntry('cuDNN', ['cudnn*.dll']),
      const MapEntry('CUDA', ['nvcuda.dll', 'nvcuda64.dll', 'cudart64_*.dll', 'cublas64_*.dll']),
      const MapEntry('Vulkan', ['vulkan-1.dll']),
      const MapEntry('D3D12', ['d3d12core.dll']),
      const MapEntry('OpenGL', ['opengl32.dll']),
      const MapEntry('D3D11', ['d3d11.dll']),
      const MapEntry('NVENC', ['nvencodeapi64.dll']),
      const MapEntry('NVDEC', ['nvcuvid.dll', 'nvcuvid64.dll']),
    ];

    for (final entry in specs) {
      _runtimePatterns.add(
        MapEntry(entry.key, entry.value.map(glob).toList()),
      );
    }
    return _runtimePatterns;
  }

  static const Set<String> _browsers = {
    'msedge.exe',
    'chrome.exe',
    'firefox.exe',
    'msedgewebview2.exe',
    'brave.exe',
    'opera.exe',
    'arc.exe',
    'vivaldi.exe',
  };

  static const Set<String> _aiRuntimes = {
    'llama.cpp',
    'whisper.cpp',
    'ggml',
    'PyTorch',
    'TensorRT',
    'ONNX RT',
    'DirectML',
    'cuDNN',
  };

  static const List<String> _llmNames = [
    'llama-',
    'llama.',
    'ollama',
    'lm studio',
    'lmstudio',
    'llmster',
    'koboldcpp',
    'jan',
    'gpt4all',
    'llamafile',
  ];

  static const Map<int, String> _ggufFileTypes = {
    0: 'F32',
    1: 'F16',
    2: 'Q4_0',
    3: 'Q4_1',
    7: 'Q8_0',
    8: 'Q5_0',
    9: 'Q5_1',
    10: 'Q2_K',
    11: 'Q3_K_S',
    12: 'Q3_K_M',
    13: 'Q3_K_L',
    14: 'Q4_K_S',
    15: 'Q4_K_M',
    16: 'Q5_K_S',
    17: 'Q5_K_M',
    18: 'Q6_K',
    19: 'IQ2_XXS',
    20: 'IQ2_XS',
    21: 'Q2_K_S',
    22: 'IQ3_XS',
    23: 'IQ3_XXS',
    24: 'IQ1_S',
    25: 'IQ4_NL',
    26: 'IQ3_S',
    27: 'IQ3_M',
    28: 'IQ2_S',
    29: 'IQ2_M',
    30: 'IQ4_XS',
    31: 'IQ1_M',
    32: 'BF16',
    36: 'TQ1_0',
    37: 'TQ2_0',
    38: 'MXFP4_MOE',
  };

  // Native PDH bindings
  int Function(Pointer<Utf16>, int, Pointer<IntPtr>)? _pdhOpenQueryW;
  int Function(int, Pointer<Utf16>, int, Pointer<IntPtr>)? _pdhAddEnglishCounterW;
  int Function(int)? _pdhCollectQueryData;
  int Function(int, int, Pointer<Uint32>, Pointer<Uint32>, Pointer<Uint8>)? _pdhGetFormattedCounterArrayW;
  int Function(int)? _pdhCloseQuery;

  int _pdhQuery = 0;
  final Map<String, int> _counterHandles = {};
  bool _pdhInitialized = false;
  bool _pdhUnavailable = false;

  // Native kernel32 module enumeration bindings
  DynamicLibrary? _kernel32;
  int Function(int, Pointer<IntPtr>, int, Pointer<Uint32>, int)? _k32EnumProcessModulesEx;
  int Function(int, int, Pointer<Utf16>, int)? _k32GetModuleBaseNameW;

  // Adapter cache (refreshed every 5 seconds)
  List<GpuAdapterInfo> _cachedAdapters = [];
  DateTime _lastAdapterScan = DateTime.fromMillisecondsSinceEpoch(0);

  // Per-PID runtime DLL cache (refreshed every 30 seconds)
  final Map<int, ({DateTime ts, List<String> runtimes})> _runtimeCache = {};

  // -------------------------------------------------------------------------
  // Static Pure Helpers (Unit Testable)
  // -------------------------------------------------------------------------

  static int parseLuidKey(String hiHex, String loHex) {
    final hi = int.parse(hiHex, radix: 16);
    final lo = int.parse(loHex, radix: 16);
    return ((hi & 0xFFFFFFFF) << 32) | (lo & 0xFFFFFFFF);
  }

  static String normalizeEngineName(String rawEngine) {
    final t = rawEngine.toLowerCase();
    if (t.startsWith('3d')) return '3d';
    if (t.startsWith('compute') || t.startsWith('cuda')) return 'compute';
    if (t.startsWith('copy')) return 'copy';
    if (t.startsWith('videodecode')) return 'decode';
    if (t.startsWith('videoencode')) return 'encode';
    return 'other';
  }

  static Map<String, dynamic>? parseProcessCounterInstance(String instanceName) {
    final m = _procRe.firstMatch(instanceName);
    if (m == null) return null;
    return {
      'pid': int.parse(m.group(1)!),
      'luid': parseLuidKey(m.group(2)!, m.group(3)!),
    };
  }

  static Map<String, dynamic>? parseEngineCounterInstance(String instanceName) {
    final m = _engineRe.firstMatch(instanceName);
    if (m == null) return null;
    return {
      'pid': int.parse(m.group(1)!),
      'luid': parseLuidKey(m.group(2)!, m.group(3)!),
      'phys': int.parse(m.group(4)!),
      'eng': int.parse(m.group(5)!),
      'engtype': normalizeEngineName(m.group(6)!),
    };
  }

  static Map<String, dynamic>? parseAdapterCounterInstance(String instanceName) {
    final m = _luidPrefixRe.firstMatch(instanceName);
    if (m == null) return null;
    return {
      'luid': parseLuidKey(m.group(1)!, m.group(2)!),
    };
  }

  static List<String> classifyLoadedDlls(Iterable<String> dllNames) {
    final lowerNames = dllNames.map((n) => n.split(r'\').last.toLowerCase()).toList();
    final found = <String>[];
    for (final entry in _getRuntimePatterns()) {
      final matched = entry.value.any((rx) => lowerNames.any((name) => rx.hasMatch(name)));
      if (matched) {
        found.add(entry.key);
      }
    }
    return found;
  }

  static String classifyProcessCategory({
    required String processName,
    required List<String> runtimes,
    required Map<String, double> engines,
    required int dedicatedBytes,
  }) {
    final lower = processName.toLowerCase();
    if (lower == 'dwm.exe' || lower == 'csrss.exe') {
      return 'Compositor';
    }
    if (_browsers.contains(lower)) {
      return 'Browser';
    }
    final isAiRuntime = runtimes.any(_aiRuntimes.contains);
    final isLlmName = _llmNames.any((n) => lower.contains(n));
    if (isAiRuntime || isLlmName) {
      return 'LLM / AI';
    }
    final decode = engines['decode'] ?? 0.0;
    final encode = engines['encode'] ?? 0.0;
    if (decode > 1.0 || encode > 1.0 || runtimes.contains('NVDEC') || runtimes.contains('NVENC')) {
      return 'Video';
    }
    final eng3d = engines['3d'] ?? 0.0;
    if (eng3d > 10.0) {
      return '3D / Game';
    }
    if (dedicatedBytes > 0 || engines.isNotEmpty || runtimes.isNotEmpty) {
      return 'Graphics';
    }
    return '';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(2)} GB';
    }
    final mb = bytes / (1024 * 1024);
    if (mb >= 0.1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  /// Parses a GGUF v1/v2/v3 header buffer and estimates Weights / KV Cache / Compute.
  static GgufModelInfo? parseGgufHeaderBytes(
    Uint8List bytes, {
    required String fileName,
    required int fileSizeBytes,
    int contextLength = 4096,
  }) {
    if (bytes.length < 16) return null;
    // Magic "GGUF" -> 0x47, 0x47, 0x55, 0x46
    if (bytes[0] != 0x47 || bytes[1] != 0x47 || bytes[2] != 0x55 || bytes[3] != 0x46) {
      return null;
    }

    final bd = ByteData.sublistView(bytes);
    int offset = 4;
    final version = bd.getUint32(offset, Endian.little);
    offset += 4;
    if (version < 1 || version > 4) return null;

    int readLen() {
      if (version >= 2) {
        if (offset + 8 > bytes.length) throw const FormatException('EOF');
        final val = bd.getUint64(offset, Endian.little);
        offset += 8;
        return val;
      } else {
        if (offset + 4 > bytes.length) throw const FormatException('EOF');
        final val = bd.getUint32(offset, Endian.little);
        offset += 4;
        return val;
      }
    }

    String readString() {
      final len = readLen();
      if (len < 0 || offset + len > bytes.length) throw const FormatException('EOF');
      final s = utf8.decode(bytes.sublist(offset, offset + len), allowMalformed: true);
      offset += len;
      return s;
    }

    dynamic readScalar(int vtype) {
      switch (vtype) {
        case 0: // uint8
          if (offset + 1 > bytes.length) throw const FormatException('EOF');
          return bd.getUint8(offset++);
        case 1: // int8
          if (offset + 1 > bytes.length) throw const FormatException('EOF');
          return bd.getInt8(offset++);
        case 2: // uint16
          if (offset + 2 > bytes.length) throw const FormatException('EOF');
          final v = bd.getUint16(offset, Endian.little);
          offset += 2;
          return v;
        case 3: // int16
          if (offset + 2 > bytes.length) throw const FormatException('EOF');
          final v = bd.getInt16(offset, Endian.little);
          offset += 2;
          return v;
        case 4: // uint32
          if (offset + 4 > bytes.length) throw const FormatException('EOF');
          final v = bd.getUint32(offset, Endian.little);
          offset += 4;
          return v;
        case 5: // int32
          if (offset + 4 > bytes.length) throw const FormatException('EOF');
          final v = bd.getInt32(offset, Endian.little);
          offset += 4;
          return v;
        case 6: // float32
          if (offset + 4 > bytes.length) throw const FormatException('EOF');
          final v = bd.getFloat32(offset, Endian.little);
          offset += 4;
          return v;
        case 7: // bool
          if (offset + 1 > bytes.length) throw const FormatException('EOF');
          return bd.getUint8(offset++) != 0;
        case 10: // uint64
          if (offset + 8 > bytes.length) throw const FormatException('EOF');
          final v = bd.getUint64(offset, Endian.little);
          offset += 8;
          return v;
        case 11: // int64
          if (offset + 8 > bytes.length) throw const FormatException('EOF');
          final v = bd.getInt64(offset, Endian.little);
          offset += 8;
          return v;
        case 12: // float64
          if (offset + 8 > bytes.length) throw const FormatException('EOF');
          final v = bd.getFloat64(offset, Endian.little);
          offset += 8;
          return v;
        default:
          throw FormatException('Unsupported GGUF scalar type $vtype');
      }
    }

    dynamic readValue(int vtype) {
      if (vtype == 8) return readString();
      if (vtype == 9) {
        if (offset + 4 > bytes.length) throw const FormatException('EOF');
        final etype = bd.getUint32(offset, Endian.little);
        offset += 4;
        final count = readLen();
        if (etype == 8) {
          for (int i = 0; i < count; i++) {
            readString();
          }
          return '<string[$count]>';
        }
        const scalarSizes = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8};
        final sz = scalarSizes[etype];
        if (sz != null) {
          final total = sz * count;
          if (offset + total > bytes.length) throw const FormatException('EOF');
          offset += total;
          return '<array[$count]>';
        }
        for (int i = 0; i < count; i++) {
          readValue(etype);
        }
        return '<array[$count]>';
      }
      return readScalar(vtype);
    }

    final metadata = <String, dynamic>{};
    try {
      readLen(); // tensorCount
      final kvCount = readLen();
      final maxKvs = min(kvCount, 512);
      for (int i = 0; i < maxKvs; i++) {
        final key = readString();
        if (offset + 4 > bytes.length) break;
        final vtype = bd.getUint32(offset, Endian.little);
        offset += 4;
        metadata[key] = readValue(vtype);
      }
    } catch (_) {
      // Partial header reads still yield whatever metadata was parsed before truncation
    }

    final arch = (metadata['general.architecture'] ?? 'llama').toString();
    final modelName = (metadata['general.name'] ?? fileName).toString();
    final ftRaw = metadata['general.file_type'];
    final ft = ftRaw is int ? ftRaw : null;
    final quant = ft != null ? (_ggufFileTypes[ft] ?? 'type$ft') : '?';

    final nLayers = (metadata['$arch.block_count'] as num?)?.toInt() ?? 0;
    final nHead = (metadata['$arch.attention.head_count'] as num?)?.toInt() ?? 0;
    final nKv = (metadata['$arch.attention.head_count_kv'] as num?)?.toInt() ?? nHead;
    final nEmbd = (metadata['$arch.embedding_length'] as num?)?.toInt() ?? 0;

    int kvPerToken = 0;
    if (nLayers > 0 && nKv > 0 && nEmbd > 0 && nHead > 0) {
      final headDim = nEmbd ~/ nHead;
      final kLen = (metadata['$arch.attention.key_length'] as num?)?.toInt() ?? headDim;
      final vLen = (metadata['$arch.attention.value_length'] as num?)?.toInt() ?? headDim;
      kvPerToken = nLayers * nKv * (kLen + vLen) * 2; // f16 KV = 2 bytes
    }

    final estWeights = fileSizeBytes > 0 ? (fileSizeBytes * 0.94).round() : 0;
    final estKv = kvPerToken > 0 ? kvPerToken * contextLength : (estWeights * 0.12).round();
    final estCompute = max(64 * 1024 * 1024, (estWeights * 0.04).round());

    return GgufModelInfo(
      fileName: modelName,
      architecture: arch,
      quantization: quant,
      fileSizeBytes: fileSizeBytes,
      estimatedWeightsBytes: estWeights,
      estimatedKvCacheBytes: estKv,
      estimatedComputeBytes: estCompute,
      evidence: 'header',
    );
  }

  static GgufModelInfo? inspectGgufFile(String path, {int contextLength = 4096}) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final len = file.lengthSync();
      if (len < 16) return null;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final readSize = min(len, 4 * 1024 * 1024);
        final bytes = raf.readSync(readSize);
        return parseGgufHeaderBytes(
          bytes,
          fileName: path.split(Platform.pathSeparator).last,
          fileSizeBytes: len,
          contextLength: contextLength,
        );
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }

  /// Diffs two GPU snapshots (`gputaskman/diff.py`), pairing processes first by PID
  /// (when names match or both are unnamed), then by process name (largest VRAM first).
  static GpuSnapshotDiff diffSnapshots(
    GpuSnapshot before,
    GpuSnapshot after, {
    int adapterIndex = 0,
    Map<int, String> beforeNames = const {},
    Map<int, String> afterNames = const {},
  }) {
    final beforeAdapter = before.adapters.isNotEmpty
        ? before.adapters[adapterIndex.clamp(0, before.adapters.length - 1)]
        : null;
    final afterAdapter = after.adapters.isNotEmpty
        ? after.adapters[adapterIndex.clamp(0, after.adapters.length - 1)]
        : null;

    final dedicatedDelta =
        (afterAdapter?.dedicatedUsedBytes ?? 0) - (beforeAdapter?.dedicatedUsedBytes ?? 0);
    final sharedDelta =
        (afterAdapter?.sharedUsedBytes ?? 0) - (beforeAdapter?.sharedUsedBytes ?? 0);
    final attributedDelta =
        (afterAdapter?.attributedVramBytes ?? 0) - (beforeAdapter?.attributedVramBytes ?? 0);
    final unattributedDelta =
        (afterAdapter?.unattributedVramBytes ?? 0) - (beforeAdapter?.unattributedVramBytes ?? 0);

    String resolveName(int pid, Map<int, String> names, ProcessGpuTelemetry p) {
      final n = names[pid];
      if (n != null && n.trim().isNotEmpty) return n.trim();
      if (p.category.isNotEmpty) return 'PID $pid (${p.category})';
      return 'PID $pid';
    }

    final pairedBefore = <int>{};
    final pairedAfter = <int>{};
    final diffs = <ProcessGpuDiff>[];

    // 1. Pair by matching PID where process names match (or both lack resolved names)
    for (final entry in after.processMap.entries) {
      final pid = entry.key;
      final a = entry.value;
      final b = before.processMap[pid];
      if (b == null) continue;
      final aRaw = beforeNames[pid]?.trim().toLowerCase() ?? '';
      final bRaw = afterNames[pid]?.trim().toLowerCase() ?? '';
      if (aRaw.isNotEmpty && bRaw.isNotEmpty && aRaw != bRaw) continue;

      pairedBefore.add(pid);
      pairedAfter.add(pid);
      diffs.add(
        ProcessGpuDiff(
          pidBefore: pid,
          pidAfter: pid,
          name: resolveName(pid, afterNames, a),
          category: a.category.isNotEmpty ? a.category : b.category,
          status: 'paired',
          dedicatedBefore: b.dedicatedBytes,
          dedicatedAfter: a.dedicatedBytes,
          sharedBefore: b.sharedBytes,
          sharedAfter: a.sharedBytes,
          committedBefore: b.committedBytes,
          committedAfter: a.committedBytes,
        ),
      );
    }

    // 2. Pair remaining processes by name (for restarted processes with new PIDs)
    final unmatchedBefore = <String, List<MapEntry<int, ProcessGpuTelemetry>>>{};
    for (final entry in before.processMap.entries) {
      if (pairedBefore.contains(entry.key)) continue;
      final rawName = beforeNames[entry.key]?.trim().toLowerCase() ?? '';
      if (rawName.isEmpty) continue;
      unmatchedBefore.putIfAbsent(rawName, () => []).add(entry);
    }
    for (final list in unmatchedBefore.values) {
      list.sort((a, b) => b.value.dedicatedBytes.compareTo(a.value.dedicatedBytes));
    }

    final remainingAfter = after.processMap.entries
        .where((e) => !pairedAfter.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.dedicatedBytes.compareTo(a.value.dedicatedBytes));

    for (final entry in remainingAfter) {
      final pid = entry.key;
      final a = entry.value;
      final rawName = afterNames[pid]?.trim().toLowerCase() ?? '';
      if (rawName.isEmpty) continue;
      final candidates = unmatchedBefore[rawName];
      if (candidates == null || candidates.isEmpty) continue;
      final matched = candidates.removeAt(0);
      final b = matched.value;
      pairedBefore.add(matched.key);
      pairedAfter.add(pid);
      diffs.add(
        ProcessGpuDiff(
          pidBefore: matched.key,
          pidAfter: pid,
          name: resolveName(pid, afterNames, a),
          category: a.category.isNotEmpty ? a.category : b.category,
          status: 'paired',
          dedicatedBefore: b.dedicatedBytes,
          dedicatedAfter: a.dedicatedBytes,
          sharedBefore: b.sharedBytes,
          sharedAfter: a.sharedBytes,
          committedBefore: b.committedBytes,
          committedAfter: a.committedBytes,
        ),
      );
    }

    // 3. New processes (only in after)
    for (final entry in after.processMap.entries) {
      if (pairedAfter.contains(entry.key)) continue;
      final a = entry.value;
      diffs.add(
        ProcessGpuDiff(
          pidBefore: null,
          pidAfter: entry.key,
          name: resolveName(entry.key, afterNames, a),
          category: a.category,
          status: 'new',
          dedicatedBefore: 0,
          dedicatedAfter: a.dedicatedBytes,
          sharedBefore: 0,
          sharedAfter: a.sharedBytes,
          committedBefore: 0,
          committedAfter: a.committedBytes,
        ),
      );
    }

    // 4. Gone processes (only in before)
    for (final entry in before.processMap.entries) {
      if (pairedBefore.contains(entry.key)) continue;
      final b = entry.value;
      diffs.add(
        ProcessGpuDiff(
          pidBefore: entry.key,
          pidAfter: null,
          name: resolveName(entry.key, beforeNames, b),
          category: b.category,
          status: 'gone',
          dedicatedBefore: b.dedicatedBytes,
          dedicatedAfter: 0,
          sharedBefore: b.sharedBytes,
          sharedAfter: 0,
          committedBefore: b.committedBytes,
          committedAfter: 0,
        ),
      );
    }

    diffs.sort((a, b) {
      final dCmp = b.dedicatedDelta.abs().compareTo(a.dedicatedDelta.abs());
      if (dCmp != 0) return dCmp;
      return b.committedDelta.abs().compareTo(a.committedDelta.abs());
    });

    return GpuSnapshotDiff(
      adapterName: afterAdapter?.adapter.name ?? beforeAdapter?.adapter.name ?? 'GPU',
      dedicatedDelta: dedicatedDelta,
      sharedDelta: sharedDelta,
      attributedDelta: attributedDelta,
      unattributedDelta: unattributedDelta,
      processes: diffs,
    );
  }

  static final RegExp _llamaBufRe = RegExp(
    r'(\S+)\s+(model|KV|compute|output|RS)\s+buffer size\s*=\s*([\d.]+)\s*MiB',
  );
  static final RegExp _ollamaBufRe = RegExp(
    r'msg="(model weights|kv cache|compute graph)"\s+device=(\S+)\s+size="([\d.]+)\s*(GiB|MiB|KiB|B)"',
  );

  /// Parses llama.cpp and Ollama server load logs (`gputaskman/llm.py`) into
  /// `{device: {'weights': bytes, 'kv': bytes, 'compute': bytes}}`.
  static Map<String, Map<String, int>>? parseLlmLoadLogContent(String text) {
    final llamaBlocks = <Map<String, Map<String, int>>>[];
    var curLlama = <String, Map<String, int>>{};
    final ollamaBlocks = <Map<String, Map<String, int>>>[];
    var curOllama = <String, Map<String, int>>{};

    int sizeToBytes(double val, String unit) {
      switch (unit) {
        case 'GiB':
          return (val * 1024 * 1024 * 1024).round();
        case 'MiB':
          return (val * 1024 * 1024).round();
        case 'KiB':
          return (val * 1024).round();
        default:
          return val.round();
      }
    }

    for (final rawLine in const LineSplitter().convert(text)) {
      final lm = _llamaBufRe.firstMatch(rawLine);
      if (lm != null) {
        final dev = lm.group(1)!;
        final kind = lm.group(2)!;
        final bytes = (double.parse(lm.group(3)!) * 1024 * 1024).round();
        if (kind == 'model' && curLlama.containsKey(dev) && curLlama[dev]!.containsKey('kv')) {
          llamaBlocks.add(curLlama);
          curLlama = {};
        }
        final entry = curLlama.putIfAbsent(dev, () => {'weights': 0, 'kv': 0, 'compute': 0});
        final bucket = (kind == 'model' || kind == 'output')
            ? 'weights'
            : (kind == 'KV' || kind == 'RS')
                ? 'kv'
                : 'compute';
        entry[bucket] = (entry[bucket] ?? 0) + bytes;
        continue;
      }

      final om = _ollamaBufRe.firstMatch(rawLine);
      if (om != null) {
        final kind = om.group(1)!;
        final dev = om.group(2)!;
        final bytes = sizeToBytes(double.parse(om.group(3)!), om.group(4)!);
        if (kind == 'model weights' && curOllama.containsKey(dev)) {
          ollamaBlocks.add(curOllama);
          curOllama = {};
        }
        final entry = curOllama.putIfAbsent(dev, () => {'weights': 0, 'kv': 0, 'compute': 0});
        final bucket = kind == 'model weights'
            ? 'weights'
            : kind == 'kv cache'
                ? 'kv'
                : 'compute';
        entry[bucket] = (entry[bucket] ?? 0) + bytes;
      }
    }

    if (curLlama.isNotEmpty) llamaBlocks.add(curLlama);
    if (curOllama.isNotEmpty) ollamaBlocks.add(curOllama);

    if (llamaBlocks.isNotEmpty) return llamaBlocks.last;
    if (ollamaBlocks.isNotEmpty) return ollamaBlocks.last;
    return null;
  }

  /// Reads the trailing 512 KiB of `%LOCALAPPDATA%\Ollama\server.log` on Windows
  /// to extract the most recent model/KV/compute buffer allocations.
  static Map<String, Map<String, int>>? readOllamaServerLogBuffers() {
    if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') return null;
    try {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.isEmpty) return null;
      final logFile = File('$localAppData\\Ollama\\server.log');
      if (!logFile.existsSync()) return null;
      final len = logFile.lengthSync();
      const tailBytes = 512 * 1024;
      final raf = logFile.openSync(mode: FileMode.read);
      try {
        if (len > tailBytes) {
          raf.setPositionSync(len - tailBytes);
        }
        final bytes = raf.readSync(min(len, tailBytes));
        final content = utf8.decode(bytes, allowMalformed: true);
        return parseLlmLoadLogContent(content);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }

  /// Resolves friendly model names from local Hugging Face, LM Studio, or Ollama
  /// model store paths (`gputaskman/stores.py`).
  static String? resolveModelStoreFriendlyName(String filePath) {
    if (filePath.trim().isEmpty) return null;
    final norm = filePath.replaceAll('\\', '/');

    // Hugging Face hub cache: .../models--<org>--<repo>/blobs/...
    final hfMatch = RegExp(r'models--([^/]+)--([^/]+)').firstMatch(norm);
    if (hfMatch != null) {
      return '${hfMatch.group(1)}/${hfMatch.group(2)}';
    }

    // LM Studio cache: .../.lmstudio/models/<publisher>/<model>/<file>.gguf
    final lmsMatch = RegExp(r'(?:\.lmstudio|lm-studio)/models/(.+)$', caseSensitive: false)
        .firstMatch(norm);
    if (lmsMatch != null) {
      var rel = lmsMatch.group(1)!;
      if (rel.toLowerCase().endsWith('.gguf')) {
        rel = rel.substring(0, rel.length - 5);
      }
      return rel;
    }

    // Ollama blob path: .../.ollama/models/blobs/sha256-<hex>
    final ollamaMatch = RegExp(r'\.ollama/models/blobs/(sha256-[0-9a-fA-F]+)$').firstMatch(norm);
    if (ollamaMatch != null) {
      final digest = ollamaMatch.group(1)!.replaceFirst('sha256-', 'sha256:');
      final shortHash = digest.length > 19 ? digest.substring(0, 19) : digest;
      return 'ollama ($shortHash)';
    }

    return null;
  }

  static const Map<int, String> _nvmlThrottleBits = {
    0x0000000000000002: 'app-clocks',
    0x0000000000000004: 'sw-power-cap',
    0x0000000000000008: 'hw-slowdown',
    0x0000000000000020: 'sw-thermal',
    0x0000000000000040: 'hw-thermal',
    0x0000000000000080: 'power-brake',
  };

  /// Decodes an NVML clock throttle reason bitmask (`gputaskman/nvml.py`).
  static List<String> decodeNvmlThrottleReasons(int bitmask) {
    final reasons = <String>[];
    for (final entry in _nvmlThrottleBits.entries) {
      if ((bitmask & entry.key) != 0) {
        reasons.add(entry.value);
      }
    }
    return reasons;
  }

  // -------------------------------------------------------------------------
  // Native Windows Adapter & PDH Sampling
  // -------------------------------------------------------------------------

  void _initPdhIfNeeded() {
    if (_pdhInitialized || _pdhUnavailable || !Platform.isWindows) return;
    try {
      final lib = DynamicLibrary.open('pdh.dll');
      _pdhOpenQueryW = lib.lookupFunction<
          Uint32 Function(Pointer<Utf16>, IntPtr, Pointer<IntPtr>),
          int Function(Pointer<Utf16>, int, Pointer<IntPtr>)>('PdhOpenQueryW');
      _pdhAddEnglishCounterW = lib.lookupFunction<
          Uint32 Function(IntPtr, Pointer<Utf16>, IntPtr, Pointer<IntPtr>),
          int Function(int, Pointer<Utf16>, int, Pointer<IntPtr>)>('PdhAddEnglishCounterW');
      _pdhCollectQueryData = lib.lookupFunction<Uint32 Function(IntPtr), int Function(int)>('PdhCollectQueryData');
      _pdhGetFormattedCounterArrayW = lib.lookupFunction<
          Uint32 Function(IntPtr, Uint32, Pointer<Uint32>, Pointer<Uint32>, Pointer<Uint8>),
          int Function(int, int, Pointer<Uint32>, Pointer<Uint32>, Pointer<Uint8>)>('PdhGetFormattedCounterArrayW');
      _pdhCloseQuery = lib.lookupFunction<Uint32 Function(IntPtr), int Function(int)>('PdhCloseQuery');

      final queryPtr = calloc<IntPtr>();
      final status = _pdhOpenQueryW!(nullptr, 0, queryPtr);
      if (status != 0) {
        calloc.free(queryPtr);
        _pdhUnavailable = true;
        return;
      }
      _pdhQuery = queryPtr.value;
      calloc.free(queryPtr);

      const counters = <String, List<String>>{
        'dedicated': [
          r'\GPU Process Memory(*)\Local Usage',
          r'\GPU Process Memory(*)\Dedicated Usage',
        ],
        'shared': [
          r'\GPU Process Memory(*)\Non Local Usage',
          r'\GPU Process Memory(*)\Shared Usage',
        ],
        'committed': [r'\GPU Process Memory(*)\Total Committed'],
        'engine': [r'\GPU Engine(*)\Utilization Percentage'],
        'a_dedicated': [r'\GPU Adapter Memory(*)\Dedicated Usage'],
        'a_shared': [r'\GPU Adapter Memory(*)\Shared Usage'],
      };

      for (final entry in counters.entries) {
        for (final path in entry.value) {
          final pathPtr = path.toNativeUtf16();
          final hCounter = calloc<IntPtr>();
          final res = _pdhAddEnglishCounterW!(_pdhQuery, pathPtr, 0, hCounter);
          calloc.free(pathPtr);
          if (res == 0) {
            _counterHandles[entry.key] = hCounter.value;
            calloc.free(hCounter);
            break;
          }
          calloc.free(hCounter);
        }
      }

      // Initial baseline sample for rate counters (GPU Engine Utilization Percentage)
      _pdhCollectQueryData!(_pdhQuery);
      _pdhInitialized = true;
    } catch (_) {
      _pdhUnavailable = true;
    }
  }

  List<({String name, double value})> _readPdhCounterArray(String key) {
    final handle = _counterHandles[key];
    if (handle == null || _pdhGetFormattedCounterArrayW == null) return const [];

    final sizePtr = calloc<Uint32>();
    final countPtr = calloc<Uint32>();
    const fmt = _pdhFmtDouble | _pdhFmtNocap100;

    final out = <({String name, double value})>[];
    try {
      final status1 = _pdhGetFormattedCounterArrayW!(handle, fmt, sizePtr, countPtr, nullptr);
      if (status1 != _pdhMoreData || sizePtr.value == 0) {
        return out;
      }
      final bufSize = sizePtr.value;
      final buf = calloc<Uint8>(bufSize);
      try {
        final status2 = _pdhGetFormattedCounterArrayW!(handle, fmt, sizePtr, countPtr, buf);
        if (status2 == 0) {
          final items = buf.cast<PdhFmtCounterValueItemW>();
          final n = countPtr.value;
          for (int i = 0; i < n; i++) {
            final item = items[i];
            if ((item.cStatus == 0 || item.cStatus == 1) && item.szName != nullptr) {
              out.add((name: item.szName.toDartString(), value: item.doubleValue));
            }
          }
        }
      } finally {
        calloc.free(buf);
      }
    } finally {
      calloc.free(sizePtr);
      calloc.free(countPtr);
    }
    return out;
  }

  List<GpuAdapterInfo> _enumerateDxgiAdapters() {
    if (!Platform.isWindows) return const [];
    final now = DateTime.now();
    if (_cachedAdapters.isNotEmpty && now.difference(_lastAdapterScan).inSeconds < 5) {
      return _cachedAdapters;
    }

    final found = <GpuAdapterInfo>[];
    try {
      final dxgi = DynamicLibrary.open('dxgi.dll');
      final createFactory1 = dxgi.lookupFunction<
          Int32 Function(Pointer<_DxgiGuid>, Pointer<Pointer<Void>>),
          int Function(Pointer<_DxgiGuid>, Pointer<Pointer<Void>>)>('CreateDXGIFactory1');

      // IID_IDXGIFactory1: {770AAE78-F26F-4DBA-A829-253C83D1B387}
      final iid = calloc<_DxgiGuid>();
      iid.ref.d1 = 0x770AAE78;
      iid.ref.d2 = 0xF26F;
      iid.ref.d3 = 0x4DBA;
      const d4Bytes = [0xA8, 0x29, 0x25, 0x3C, 0x83, 0xD1, 0xB3, 0x87];
      for (int i = 0; i < 8; i++) {
        iid.ref.d4[i] = d4Bytes[i];
      }

      final factoryPtr = calloc<Pointer<Void>>();
      try {
        final hr = createFactory1(iid, factoryPtr);
        if (hr == 0 && factoryPtr.value != nullptr) {
          final factory = factoryPtr.value;
          final factoryVtbl = factory.cast<Pointer<Pointer<Void>>>().value;
          final enumAdapters1 = factoryVtbl[12].cast<
              NativeFunction<Int32 Function(Pointer<Void>, Uint32, Pointer<Pointer<Void>>)>>()
              .asFunction<int Function(Pointer<Void>, int, Pointer<Pointer<Void>>)>();
          final releaseFactory = factoryVtbl[2]
              .cast<NativeFunction<Uint32 Function(Pointer<Void>)>>()
              .asFunction<int Function(Pointer<Void>)>();

          final adapterPtr = calloc<Pointer<Void>>();
          final descPtr = calloc<_DxgiAdapterDesc1>();
          try {
            int idx = 0;
            while (true) {
              final status = enumAdapters1(factory, idx, adapterPtr);
              if (status != 0 || status.toUnsigned(32) == _dxgiErrorNotFound) break;

              final adapter = adapterPtr.value;
              if (adapter != nullptr) {
                final adapterVtbl = adapter.cast<Pointer<Pointer<Void>>>().value;
                final getDesc1 = adapterVtbl[10]
                    .cast<NativeFunction<Int32 Function(Pointer<Void>, Pointer<_DxgiAdapterDesc1>)>>()
                    .asFunction<int Function(Pointer<Void>, Pointer<_DxgiAdapterDesc1>)>();
                final releaseAdapter = adapterVtbl[2]
                    .cast<NativeFunction<Uint32 Function(Pointer<Void>)>>()
                    .asFunction<int Function(Pointer<Void>)>();

                if (getDesc1(adapter, descPtr) == 0) {
                  final codeUnits = <int>[];
                  for (int c = 0; c < 128; c++) {
                    final ch = descPtr.ref.description[c];
                    if (ch == 0) break;
                    codeUnits.add(ch);
                  }
                  final name = String.fromCharCodes(codeUnits).trim();
                  final luid = ((descPtr.ref.luidHighPart & 0xFFFFFFFF) << 32) |
                      (descPtr.ref.luidLowPart & 0xFFFFFFFF);
                  final isSoft = (descPtr.ref.flags & 2) != 0 || descPtr.ref.vendorId == 0x1414;
                  found.add(
                    GpuAdapterInfo(
                      luid: luid,
                      name: name.isNotEmpty ? name : 'Display Adapter $idx',
                      vendorId: descPtr.ref.vendorId,
                      dedicatedVramBytes: descPtr.ref.dedicatedVideoMemory,
                      sharedSystemBytes: descPtr.ref.sharedSystemMemory,
                      isSoftware: isSoft,
                    ),
                  );
                }
                releaseAdapter(adapter);
              }
              idx++;
            }
          } finally {
            calloc.free(adapterPtr);
            calloc.free(descPtr);
            releaseFactory(factory);
          }
        }
      } finally {
        calloc.free(iid);
        calloc.free(factoryPtr);
      }
    } catch (_) {}

    final hw = found.where((a) => !a.isSoftware).toList();
    final list = hw.isNotEmpty ? hw : found;
    // Order: NVIDIA first, then AMD, then Intel, largest dedicated VRAM first
    int vendorRank(int v) {
      if (v == 0x10DE) return 0;
      if (v == 0x1002) return 1;
      if (v == 0x8086) return 2;
      return 3;
    }

    list.sort((a, b) {
      final vr = vendorRank(a.vendorId).compareTo(vendorRank(b.vendorId));
      if (vr != 0) return vr;
      return b.dedicatedVramBytes.compareTo(a.dedicatedVramBytes);
    });

    if (list.isNotEmpty) {
      _cachedAdapters = list;
      _lastAdapterScan = now;
    }
    return list;
  }

  List<String> _getProcessRuntimes(int pid) {
    final now = DateTime.now();
    final cached = _runtimeCache[pid];
    if (cached != null && now.difference(cached.ts).inSeconds < 30) {
      return cached.runtimes;
    }
    if (!Platform.isWindows) return const [];

    try {
      _kernel32 ??= DynamicLibrary.open('kernel32.dll');
      _k32EnumProcessModulesEx ??= _kernel32!.lookupFunction<
          Int32 Function(IntPtr, Pointer<IntPtr>, Uint32, Pointer<Uint32>, Uint32),
          int Function(int, Pointer<IntPtr>, int, Pointer<Uint32>, int)>('K32EnumProcessModulesEx');
      _k32GetModuleBaseNameW ??= _kernel32!.lookupFunction<
          Uint32 Function(IntPtr, IntPtr, Pointer<Utf16>, Uint32),
          int Function(int, int, Pointer<Utf16>, int)>('K32GetModuleBaseNameW');
    } catch (_) {
      return const [];
    }

    final dllNames = <String>[];
    final openRes = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, false, pid);
    final hProcess = openRes.value;
    if (hProcess == nullptr) {
      _runtimeCache[pid] = (ts: now, runtimes: const []);
      return const [];
    }

    try {
      const maxModules = 256;
      final modules = calloc<IntPtr>(maxModules);
      final needed = calloc<Uint32>();
      final nameBuf = calloc<Uint16>(260).cast<Utf16>();
      try {
        final ok = _k32EnumProcessModulesEx!(
          hProcess.address,
          modules,
          maxModules * sizeOf<IntPtr>(),
          needed,
          _listModulesAll,
        );
        if (ok != 0) {
          final count = min(maxModules, needed.value ~/ sizeOf<IntPtr>());
          for (int i = 0; i < count; i++) {
            final mod = modules[i];
            if (mod == 0) continue;
            final len = _k32GetModuleBaseNameW!(hProcess.address, mod, nameBuf, 260);
            if (len > 0) {
              dllNames.add(nameBuf.toDartString());
            }
          }
        }
      } finally {
        calloc.free(modules);
        calloc.free(needed);
        calloc.free(nameBuf);
      }
    } finally {
      CloseHandle(hProcess);
    }

    final runtimes = classifyLoadedDlls(dllNames);
    _runtimeCache[pid] = (ts: now, runtimes: runtimes);
    return runtimes;
  }

  /// Collects a full GPU snapshot for [selectedAdapterIndex].
  /// Pass [processNamesByPid] to enrich category classification and LLM detection.
  GpuSnapshot sample({
    int selectedAdapterIndex = 0,
    Map<int, String> processNamesByPid = const {},
  }) {
    if (Platform.environment['FLUTTER_TEST'] == 'true' || !Platform.isWindows) {
      return _simulatedSnapshot(selectedAdapterIndex);
    }

    final adapters = _enumerateDxgiAdapters();
    if (adapters.isEmpty) {
      return _simulatedSnapshot(selectedAdapterIndex);
    }

    _initPdhIfNeeded();
    if (!_pdhInitialized || _pdhCollectQueryData == null || _pdhCollectQueryData!(_pdhQuery) != 0) {
      return GpuSnapshot(
        adapters: adapters
            .map(
              (a) => AdapterGpuTelemetry(
                adapter: a,
                dedicatedUsedBytes: 0,
                sharedUsedBytes: 0,
                attributedVramBytes: 0,
                gpuUtilizationPercent: 0.0,
              ),
            )
            .toList(),
        processMap: const {},
      );
    }

    // Read PDH counters
    final procDedicated = <int, Map<int, double>>{};
    final procShared = <int, Map<int, double>>{};
    final procCommitted = <int, Map<int, double>>{};
    final procEngines = <int, Map<int, Map<String, double>>>{};
    final adapterEngineUsage = <int, Map<String, double>>{};
    final adapterEngineBuckets = <int, Map<String, double>>{};
    final adapterDedicated = <int, double>{};
    final adapterShared = <int, double>{};

    void accumulateProc(Map<int, Map<int, double>> target, String key) {
      for (final item in _readPdhCounterArray(key)) {
        final parsed = parseProcessCounterInstance(item.name);
        if (parsed == null) continue;
        final pid = parsed['pid'] as int;
        final luid = parsed['luid'] as int;
        final map = target.putIfAbsent(luid, () => {});
        map[pid] = (map[pid] ?? 0.0) + item.value;
      }
    }

    accumulateProc(procDedicated, 'dedicated');
    accumulateProc(procShared, 'shared');
    accumulateProc(procCommitted, 'committed');

    for (final item in _readPdhCounterArray('engine')) {
      final parsed = parseEngineCounterInstance(item.name);
      if (parsed == null) continue;
      final pid = parsed['pid'] as int;
      final luid = parsed['luid'] as int;
      final phys = parsed['phys'] as int;
      final eng = parsed['eng'] as int;
      final engType = parsed['engtype'] as String;

      final pMap = procEngines.putIfAbsent(luid, () => {});
      final eMap = pMap.putIfAbsent(pid, () => {});
      eMap[engType] = (eMap[engType] ?? 0.0) + item.value;

      final bucketKey = '$phys:$eng:$engType';
      final bMap = adapterEngineBuckets.putIfAbsent(luid, () => {});
      bMap[bucketKey] = (bMap[bucketKey] ?? 0.0) + item.value;
    }

    for (final entry in adapterEngineBuckets.entries) {
      final luid = entry.key;
      final summary = <String, double>{};
      for (final b in entry.value.entries) {
        final engType = b.key.split(':').last;
        final clamped = b.value.clamp(0.0, 100.0);
        final prev = summary[engType] ?? 0.0;
        if (clamped > prev) summary[engType] = clamped;
      }
      adapterEngineUsage[luid] = summary;
    }

    for (final item in _readPdhCounterArray('a_dedicated')) {
      final parsed = parseAdapterCounterInstance(item.name);
      if (parsed == null) continue;
      final luid = parsed['luid'] as int;
      adapterDedicated[luid] = (adapterDedicated[luid] ?? 0.0) + item.value;
    }
    for (final item in _readPdhCounterArray('a_shared')) {
      final parsed = parseAdapterCounterInstance(item.name);
      if (parsed == null) continue;
      final luid = parsed['luid'] as int;
      adapterShared[luid] = (adapterShared[luid] ?? 0.0) + item.value;
    }

    final activeIdx = selectedAdapterIndex.clamp(0, adapters.length - 1);
    final selectedLuid = adapters[activeIdx].luid;

    final adapterTelemetry = <AdapterGpuTelemetry>[];
    for (final adapter in adapters) {
      final luid = adapter.luid;
      final dedMap = procDedicated[luid] ?? const {};
      int attributed = 0;
      for (final v in dedMap.values) {
        attributed += v.round();
      }
      final engSummary = adapterEngineUsage[luid] ?? const {};
      double util = 0.0;
      for (final v in engSummary.values) {
        if (v > util) util = v;
      }
      adapterTelemetry.add(
        AdapterGpuTelemetry(
          adapter: adapter,
          dedicatedUsedBytes: (adapterDedicated[luid] ?? attributed.toDouble()).round(),
          sharedUsedBytes: (adapterShared[luid] ?? 0.0).round(),
          attributedVramBytes: attributed,
          gpuUtilizationPercent: util.clamp(0.0, 100.0),
          engineUtilization: engSummary,
        ),
      );
    }

    // Build process map for the selected adapter LUID
    final pids = <int>{
      ...(procDedicated[selectedLuid]?.keys ?? const []),
      ...(procShared[selectedLuid]?.keys ?? const []),
      ...(procCommitted[selectedLuid]?.keys ?? const []),
      ...(procEngines[selectedLuid]?.keys ?? const []),
    };

    final procMap = <int, ProcessGpuTelemetry>{};
    for (final pid in pids) {
      final ded = (procDedicated[selectedLuid]?[pid] ?? 0.0).round();
      final shr = (procShared[selectedLuid]?[pid] ?? 0.0).round();
      final com = (procCommitted[selectedLuid]?[pid] ?? 0.0).round();
      final eng = procEngines[selectedLuid]?[pid] ?? const {};
      final pName = processNamesByPid[pid] ?? '';
      final isActiveGpu = ded > 0 || shr > 0 || eng.values.any((v) => v > 0.1);
      final runtimes = isActiveGpu ? _getProcessRuntimes(pid) : const <String>[];
      final category = classifyProcessCategory(
        processName: pName,
        runtimes: runtimes,
        engines: eng,
        dedicatedBytes: ded,
      );

      procMap[pid] = ProcessGpuTelemetry(
        pid: pid,
        adapterLuid: selectedLuid,
        dedicatedBytes: ded,
        sharedBytes: shr,
        committedBytes: com,
        engines: eng,
        runtimes: runtimes,
        category: category,
      );
    }

    // Evict stale PIDs from runtime cache occasionally
    if (_runtimeCache.length > 256) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      _runtimeCache.removeWhere((_, val) => val.ts.isBefore(cutoff));
    }

    return GpuSnapshot(
      adapters: adapterTelemetry,
      processMap: procMap,
    );
  }

  GpuSnapshot _simulatedSnapshot(int selectedAdapterIndex) {
    const primaryAdapter = GpuAdapterInfo(
      luid: 0x0000000000012B34,
      name: 'NVIDIA GeForce RTX 4080 SUPER (Simulated)',
      vendorId: 0x10DE,
      dedicatedVramBytes: 16 * 1024 * 1024 * 1024,
      sharedSystemBytes: 16 * 1024 * 1024 * 1024,
    );

    final telemetry = AdapterGpuTelemetry(
      adapter: primaryAdapter,
      dedicatedUsedBytes: (4.8 * 1024 * 1024 * 1024).round(),
      sharedUsedBytes: (1.1 * 1024 * 1024 * 1024).round(),
      attributedVramBytes: (4.4 * 1024 * 1024 * 1024).round(),
      gpuUtilizationPercent: 28.4,
      engineUtilization: const {
        '3d': 28.4,
        'compute': 12.0,
        'copy': 3.2,
        'decode': 1.5,
        'encode': 0.0,
      },
    );

    final procMap = <int, ProcessGpuTelemetry>{
      2408: const ProcessGpuTelemetry(
        pid: 2408,
        adapterLuid: 0x0000000000012B34,
        dedicatedBytes: 1150 * 1024 * 1024,
        sharedBytes: 420 * 1024 * 1024,
        committedBytes: 1680 * 1024 * 1024,
        engines: {'3d': 14.2, 'decode': 1.5},
        runtimes: ['D3D11', 'Vulkan'],
        category: 'Browser',
      ),
      3100: const ProcessGpuTelemetry(
        pid: 3100,
        adapterLuid: 0x0000000000012B34,
        dedicatedBytes: 380 * 1024 * 1024,
        sharedBytes: 120 * 1024 * 1024,
        committedBytes: 540 * 1024 * 1024,
        engines: {'3d': 4.1},
        runtimes: ['D3D11'],
        category: 'Graphics',
      ),
      1420: const ProcessGpuTelemetry(
        pid: 1420,
        adapterLuid: 0x0000000000012B34,
        dedicatedBytes: 96 * 1024 * 1024,
        sharedBytes: 24 * 1024 * 1024,
        committedBytes: 128 * 1024 * 1024,
        engines: {'3d': 2.0},
        runtimes: ['D3D11', 'OpenGL'],
        category: 'Graphics',
      ),
    };

    return GpuSnapshot(
      adapters: [telemetry],
      processMap: procMap,
    );
  }

  void dispose() {
    if (_pdhQuery != 0 && _pdhCloseQuery != null) {
      try {
        _pdhCloseQuery!(_pdhQuery);
      } catch (_) {}
      _pdhQuery = 0;
    }
    _pdhInitialized = false;
    _counterHandles.clear();
  }
}
