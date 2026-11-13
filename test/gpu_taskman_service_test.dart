import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskman_ultimate/services/gpu_taskman_service.dart';
import 'package:taskman_ultimate/services/system_extended_service.dart';

Uint8List _buildSyntheticGgufV3Header() {
  final builder = BytesBuilder();

  void writeUint32(int v) {
    final bd = ByteData(4)..setUint32(0, v, Endian.little);
    builder.add(bd.buffer.asUint8List());
  }

  void writeUint64(int v) {
    final bd = ByteData(8)..setUint64(0, v, Endian.little);
    builder.add(bd.buffer.asUint8List());
  }

  void writeString(String s) {
    final utf = utf8.encode(s);
    writeUint64(utf.length);
    builder.add(utf);
  }

  void writeKvString(String key, String val) {
    writeString(key);
    writeUint32(8); // GGUF string
    writeString(val);
  }

  void writeKvUint32(String key, int val) {
    writeString(key);
    writeUint32(4); // GGUF uint32
    writeUint32(val);
  }

  builder.add(ascii.encode('GGUF'));
  writeUint32(3); // version 3
  writeUint64(0); // tensor_count = 0
  writeUint64(7); // kv_count = 7

  writeKvString('general.architecture', 'llama');
  writeKvString('general.name', 'Qwen2.5-7B-Instruct');
  writeKvUint32('general.file_type', 15); // Q4_K_M
  writeKvUint32('llama.block_count', 32);
  writeKvUint32('llama.attention.head_count', 32);
  writeKvUint32('llama.attention.head_count_kv', 4);
  writeKvUint32('llama.embedding_length', 4096);

  return builder.toBytes();
}

void main() {
  group('GpuTaskManService PDH & LUID parsing', () {
    test('parseLuidKey combines high and low 32-bit hex parts', () {
      expect(GpuTaskManService.parseLuidKey('00000000', '00012B34'), 0x0000000000012B34);
      expect(GpuTaskManService.parseLuidKey('00000001', '00000002'), (1 << 32) | 2);
    });

    test('normalizeEngineName maps WDDM engtypes accurately', () {
      expect(GpuTaskManService.normalizeEngineName('3D'), '3d');
      expect(GpuTaskManService.normalizeEngineName('Compute_0'), 'compute');
      expect(GpuTaskManService.normalizeEngineName('Cuda'), 'compute');
      expect(GpuTaskManService.normalizeEngineName('Copy'), 'copy');
      expect(GpuTaskManService.normalizeEngineName('VideoDecode'), 'decode');
      expect(GpuTaskManService.normalizeEngineName('VideoEncode'), 'encode');
      expect(GpuTaskManService.normalizeEngineName('HighPriority3D'), 'other');
    });

    test('parseProcessCounterInstance extracts pid and luid', () {
      final parsed = GpuTaskManService.parseProcessCounterInstance(
        'pid_2408_luid_0x00000000_0x00012B34_phys_0',
      );
      expect(parsed, isNotNull);
      expect(parsed!['pid'], 2408);
      expect(parsed['luid'], 0x0000000000012B34);
    });

    test('parseEngineCounterInstance extracts pid, luid, phys, eng, engtype', () {
      final parsed = GpuTaskManService.parseEngineCounterInstance(
        'pid_3100_luid_0x00000000_0x00012B34_phys_0_eng_2_engtype_VideoDecode',
      );
      expect(parsed, isNotNull);
      expect(parsed!['pid'], 3100);
      expect(parsed['luid'], 0x0000000000012B34);
      expect(parsed['phys'], 0);
      expect(parsed['eng'], 2);
      expect(parsed['engtype'], 'decode');
    });

    test('parseAdapterCounterInstance extracts adapter luid', () {
      final parsed = GpuTaskManService.parseAdapterCounterInstance(
        'luid_0x00000000_0x00012B34_phys_0',
      );
      expect(parsed, isNotNull);
      expect(parsed!['luid'], 0x0000000000012B34);
    });
  });

  group('GpuTaskManService Runtime & GGUF Introspection', () {
    test('classifyLoadedDlls detects AI and graphics runtimes in priority order', () {
      final runtimes = GpuTaskManService.classifyLoadedDlls([
        r'C:\Windows\System32\d3d11.dll',
        r'C:\Program Files\Ollama\ggml-cuda.dll',
        r'C:\Windows\System32\nvcuda.dll',
        r'C:\Program Files\App\llama.dll',
      ]);
      expect(runtimes, containsAll(['llama.cpp', 'ggml', 'CUDA', 'D3D11']));
      expect(runtimes.first, 'llama.cpp');
    });

    test('classifyProcessCategory identifies Compositor, Browser, LLM / AI, Video, and 3D / Game', () {
      expect(
        GpuTaskManService.classifyProcessCategory(
          processName: 'dwm.exe',
          runtimes: const ['D3D11'],
          engines: const {'3d': 2.0},
          dedicatedBytes: 120 * 1024 * 1024,
        ),
        'Compositor',
      );
      expect(
        GpuTaskManService.classifyProcessCategory(
          processName: 'chrome.exe',
          runtimes: const ['D3D11'],
          engines: const {'3d': 12.0},
          dedicatedBytes: 500 * 1024 * 1024,
        ),
        'Browser',
      );
      expect(
        GpuTaskManService.classifyProcessCategory(
          processName: 'python.exe',
          runtimes: const ['PyTorch', 'CUDA'],
          engines: const {'compute': 45.0},
          dedicatedBytes: 4000 * 1024 * 1024,
        ),
        'LLM / AI',
      );
      expect(
        GpuTaskManService.classifyProcessCategory(
          processName: 'ffmpeg.exe',
          runtimes: const ['NVENC'],
          engines: const {'encode': 80.0},
          dedicatedBytes: 256 * 1024 * 1024,
        ),
        'Video',
      );
      expect(
        GpuTaskManService.classifyProcessCategory(
          processName: 'game.exe',
          runtimes: const ['D3D12'],
          engines: const {'3d': 75.0},
          dedicatedBytes: 4096 * 1024 * 1024,
        ),
        '3D / Game',
      );
    });

    test('parseGgufHeaderBytes extracts model metadata and estimates KV cache', () {
      final header = _buildSyntheticGgufV3Header();
      const fileSize = 4680 * 1024 * 1024;
      final info = GpuTaskManService.parseGgufHeaderBytes(
        header,
        fileName: 'qwen2.5-7b-q4_k_m.gguf',
        fileSizeBytes: fileSize,
        contextLength: 4096,
      );

      expect(info, isNotNull);
      expect(info!.fileName, 'Qwen2.5-7B-Instruct');
      expect(info.architecture, 'llama');
      expect(info.quantization, 'Q4_K_M');
      expect(info.estimatedWeightsBytes, greaterThan(0));
      // 32 layers * 4 kv_heads * (128 + 128) * 2 bytes * 4096 ctx = 268,435,456 bytes (256 MiB)
      expect(info.estimatedKvCacheBytes, 268435456);
      expect(info.estimatedComputeBytes, greaterThan(0));
    });
  });

  group('GpuTaskManService Phase 2 (diff, llm logs, stores, nvml, jsonl)', () {
    test('diffSnapshots pairs by PID, matches restarted processes by name, and filters noise', () {
      const adapterBefore = AdapterGpuTelemetry(
        adapter: GpuAdapterInfo(
          luid: 1,
          name: 'RTX 4080',
          vendorId: 0x10DE,
          dedicatedVramBytes: 16 * 1024 * 1024 * 1024,
          sharedSystemBytes: 16 * 1024 * 1024 * 1024,
        ),
        dedicatedUsedBytes: 2000 * 1024 * 1024,
        sharedUsedBytes: 500 * 1024 * 1024,
        attributedVramBytes: 1900 * 1024 * 1024,
        gpuUtilizationPercent: 20.0,
      );
      const adapterAfter = AdapterGpuTelemetry(
        adapter: GpuAdapterInfo(
          luid: 1,
          name: 'RTX 4080',
          vendorId: 0x10DE,
          dedicatedVramBytes: 16 * 1024 * 1024 * 1024,
          sharedSystemBytes: 16 * 1024 * 1024 * 1024,
        ),
        dedicatedUsedBytes: 6000 * 1024 * 1024,
        sharedUsedBytes: 700 * 1024 * 1024,
        attributedVramBytes: 5900 * 1024 * 1024,
        gpuUtilizationPercent: 60.0,
      );

      final before = GpuSnapshot(
        adapters: [adapterBefore],
        processMap: const {
          100: ProcessGpuTelemetry(
            pid: 100,
            adapterLuid: 1,
            dedicatedBytes: 1000 * 1024 * 1024,
            sharedBytes: 100 * 1024 * 1024,
            committedBytes: 1200 * 1024 * 1024,
            category: 'Browser',
          ),
          200: ProcessGpuTelemetry(
            pid: 200,
            adapterLuid: 1,
            dedicatedBytes: 500 * 1024 * 1024,
            sharedBytes: 50 * 1024 * 1024,
            committedBytes: 550 * 1024 * 1024,
            category: 'LLM / AI',
          ),
          300: ProcessGpuTelemetry(
            pid: 300,
            adapterLuid: 1,
            dedicatedBytes: 400 * 1024 * 1024,
            sharedBytes: 10 * 1024 * 1024,
            committedBytes: 410 * 1024 * 1024,
            category: '3D / Game',
          ),
        },
      );

      final after = GpuSnapshot(
        adapters: [adapterAfter],
        processMap: const {
          100: ProcessGpuTelemetry(
            pid: 100,
            adapterLuid: 1,
            dedicatedBytes: 1004 * 1024 * 1024, // +4 MiB (below 16 MiB noise)
            sharedBytes: 100 * 1024 * 1024,
            committedBytes: 1204 * 1024 * 1024,
            category: 'Browser',
          ),
          201: ProcessGpuTelemetry(
            pid: 201,
            adapterLuid: 1,
            dedicatedBytes: 4500 * 1024 * 1024, // restarted ollama +4000 MiB
            sharedBytes: 200 * 1024 * 1024,
            committedBytes: 4700 * 1024 * 1024,
            category: 'LLM / AI',
          ),
          400: ProcessGpuTelemetry(
            pid: 400,
            adapterLuid: 1,
            dedicatedBytes: 300 * 1024 * 1024, // new process
            sharedBytes: 0,
            committedBytes: 300 * 1024 * 1024,
            category: 'Video',
          ),
        },
      );

      final diff = GpuTaskManService.diffSnapshots(
        before,
        after,
        beforeNames: {100: 'chrome.exe', 200: 'ollama.exe', 300: 'game.exe'},
        afterNames: {100: 'chrome.exe', 201: 'ollama.exe', 400: 'ffmpeg.exe'},
      );

      expect(diff.dedicatedDelta, 4000 * 1024 * 1024);
      expect(diff.sharedDelta, 200 * 1024 * 1024);
      expect(diff.processes.length, 4);

      final ollama = diff.processes.firstWhere((p) => p.name == 'ollama.exe');
      expect(ollama.status, 'paired');
      expect(ollama.pidBefore, 200);
      expect(ollama.pidAfter, 201);
      expect(ollama.dedicatedDelta, 4000 * 1024 * 1024);

      final goneGame = diff.processes.firstWhere((p) => p.name == 'game.exe');
      expect(goneGame.status, 'gone');
      expect(goneGame.dedicatedDelta, -400 * 1024 * 1024);

      final sig = diff.significantProcesses();
      expect(sig.any((p) => p.name == 'chrome.exe'), isFalse);
      expect(sig.length, 3);
    });

    test('parseLlmLoadLogContent parses llama.cpp and Ollama buffer logs', () {
      const llamaLog = '''
CUDA0 model buffer size =  4096.00 MiB
CUDA0 KV buffer size =  1024.00 MiB
CUDA0 compute buffer size =   256.00 MiB
''';
      final parsedLlama = GpuTaskManService.parseLlmLoadLogContent(llamaLog);
      expect(parsedLlama, isNotNull);
      expect(parsedLlama!['CUDA0']!['weights'], 4096 * 1024 * 1024);
      expect(parsedLlama['CUDA0']!['kv'], 1024 * 1024 * 1024);
      expect(parsedLlama['CUDA0']!['compute'], 256 * 1024 * 1024);

      const ollamaLog = '''
time=2026-11-13T09:00:00Z level=INFO msg="model weights" device=CUDA0 size="3.5 GiB"
time=2026-11-13T09:00:01Z level=INFO msg="kv cache" device=CUDA0 size="512.0 MiB"
time=2026-11-13T09:00:01Z level=INFO msg="compute graph" device=CUDA0 size="128.0 MiB"
''';
      final parsedOllama = GpuTaskManService.parseLlmLoadLogContent(ollamaLog);
      expect(parsedOllama, isNotNull);
      expect(parsedOllama!['CUDA0']!['kv'], 512 * 1024 * 1024);
      expect(parsedOllama['CUDA0']!['compute'], 128 * 1024 * 1024);
      expect(parsedOllama['CUDA0']!['weights'], (3.5 * 1024 * 1024 * 1024).round());
    });

    test('resolveModelStoreFriendlyName handles Hugging Face, LM Studio, and Ollama paths', () {
      expect(
        GpuTaskManService.resolveModelStoreFriendlyName(
          r'C:\Users\dev\.cache\huggingface\hub\models--Qwen--Qwen2.5-7B-Instruct-GGUF\blobs\abc',
        ),
        'Qwen/Qwen2.5-7B-Instruct-GGUF',
      );
      expect(
        GpuTaskManService.resolveModelStoreFriendlyName(
          r'C:\Users\dev\.lmstudio\models\bartowski\Llama-3.1-8B-GGUF\Llama-3.1-8B-Q4_K_M.gguf',
        ),
        'bartowski/Llama-3.1-8B-GGUF/Llama-3.1-8B-Q4_K_M',
      );
      expect(
        GpuTaskManService.resolveModelStoreFriendlyName(
          r'C:\Users\dev\.ollama\models\blobs\sha256-1234567890abcdef1234567890abcdef',
        ),
        contains('sha256:1234567890ab'),
      );
    });

    test('decodeNvmlThrottleReasons decodes active hardware/thermal bits', () {
      expect(GpuTaskManService.decodeNvmlThrottleReasons(0), isEmpty);
      expect(
        GpuTaskManService.decodeNvmlThrottleReasons(0x04 | 0x40),
        equals(['sw-power-cap', 'hw-thermal']),
      );
    });

    test('FlightRecorder generateTelemetryJsonl produces newline-delimited JSON with GPU fields', () {
      final svc = SystemExtendedService.instance;
      svc.flightRecorderLogs.clear();
      svc.isRecordingFlight = true;
      svc.recordSnapshot(
        cpu: 22.5,
        mem: 55.0,
        disk: 12.3,
        gpu: 48.0,
        gpuVramMB: 4096.0,
        topProc: 'ollama.exe',
        topProcCpu: 18.2,
      );
      final jsonl = svc.generateTelemetryJsonl();
      final lines = jsonl.trim().split('\n');
      expect(lines.length, 1);
      final decoded = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(decoded['gpuPercent'], 48.0);
      expect(decoded['gpuVramMB'], 4096.0);
      expect(decoded['topProcessName'], 'ollama.exe');
    });
  });
}

