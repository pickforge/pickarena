import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _SetenvNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _SetenvDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

typedef _SetEnvVarNative = Int32 Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _SetEnvVarDart = int Function(Pointer<Utf16>, Pointer<Utf16>);

/// Mutates the current process's OS env so that `TMPDIR` points at [path]
/// (and `TMP`/`TEMP` on Windows). Child processes started afterwards via
/// `Process.run` / `Process.start` inherit this value through the live
/// `environ` (NOT through Dart's cached `Platform.environment`). Creates
/// [path] if missing. Safe no-op if the native symbol cannot be resolved.
///
/// Untested at unit-test level: mutates real process env via dart:ffi.
/// Exercised manually by launching the app and observing where spawned
/// subprocesses write their temp files.
void bootstrapTmpDir(String path) {
  try {
    Directory(path).createSync(recursive: true);
  } catch (_) {
    return;
  }

  if (Platform.isLinux || Platform.isMacOS) {
    _posixSetenv('TMPDIR', path);
  } else if (Platform.isWindows) {
    _windowsSetEnv('TMP', path);
    _windowsSetEnv('TEMP', path);
    _windowsSetEnv('TMPDIR', path);
  }
}

void _posixSetenv(String name, String value) {
  Pointer<Utf8>? namePtr;
  Pointer<Utf8>? valuePtr;
  try {
    final libc = DynamicLibrary.process();
    final setenv = libc.lookupFunction<_SetenvNative, _SetenvDart>('setenv');
    namePtr = name.toNativeUtf8();
    valuePtr = value.toNativeUtf8();
    setenv(namePtr, valuePtr, 1);
  } catch (_) {
    // Defensive: never block app startup on a missing symbol.
  } finally {
    if (namePtr != null) calloc.free(namePtr);
    if (valuePtr != null) calloc.free(valuePtr);
  }
}

void _windowsSetEnv(String name, String value) {
  Pointer<Utf16>? namePtr;
  Pointer<Utf16>? valuePtr;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final setEnv = kernel32
        .lookupFunction<_SetEnvVarNative, _SetEnvVarDart>(
          'SetEnvironmentVariableW',
        );
    namePtr = name.toNativeUtf16();
    valuePtr = value.toNativeUtf16();
    setEnv(namePtr, valuePtr);
  } catch (_) {
    // Defensive: never block app startup on a missing symbol.
  } finally {
    if (namePtr != null) calloc.free(namePtr);
    if (valuePtr != null) calloc.free(valuePtr);
  }
}
