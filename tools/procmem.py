"""Acceso externo a la memoria de un proceso (Win32): ReadProcessMemory, regiones y módulos (incluye WOW64)."""
import ctypes
import ctypes.wintypes as wt

kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

PROCESS_VM_READ, PROCESS_QUERY_INFORMATION = 0x0010, 0x0400
MEM_COMMIT = 0x1000
PAGE_GUARD, PAGE_NOACCESS = 0x100, 0x01
TH32CS_SNAPMODULE, TH32CS_SNAPMODULE32 = 0x8, 0x10


class MBI(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_uint64), ("AllocationBase", ctypes.c_uint64), ("AllocationProtect", wt.DWORD),
                ("PartitionId", wt.WORD), ("_a", wt.WORD), ("RegionSize", ctypes.c_uint64), ("State", wt.DWORD),
                ("Protect", wt.DWORD), ("Type", wt.DWORD), ("_b", wt.DWORD)]


class MODULEENTRY32W(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("th32ModuleID", wt.DWORD), ("th32ProcessID", wt.DWORD),
                ("GlblcntUsage", wt.DWORD), ("ProccntUsage", wt.DWORD), ("modBaseAddr", ctypes.c_void_p),
                ("modBaseSize", wt.DWORD), ("hModule", wt.HMODULE), ("szModule", ctypes.c_wchar * 256),
                ("szExePath", ctypes.c_wchar * 260)]


kernel32.OpenProcess.restype = wt.HANDLE
kernel32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
kernel32.ReadProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
kernel32.VirtualQueryEx.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.POINTER(MBI), ctypes.c_size_t]
kernel32.VirtualQueryEx.restype = ctypes.c_size_t
kernel32.CreateToolhelp32Snapshot.restype = wt.HANDLE
kernel32.CreateToolhelp32Snapshot.argtypes = [wt.DWORD, wt.DWORD]
kernel32.Module32FirstW.argtypes = [wt.HANDLE, ctypes.POINTER(MODULEENTRY32W)]
kernel32.Module32NextW.argtypes = [wt.HANDLE, ctypes.POINTER(MODULEENTRY32W)]
kernel32.CloseHandle.argtypes = [wt.HANDLE]
kernel32.GetExitCodeProcess.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]


class Proc:
    def __init__(self, pid):
        self.pid = pid
        self.h = kernel32.OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, False, pid)
        if not self.h:
            raise OSError("OpenProcess(%d) falló: %d" % (pid, ctypes.get_last_error()))
        self._n = ctypes.c_size_t(0)

    def close(self):
        if self.h:
            kernel32.CloseHandle(self.h)
            self.h = None

    def alive(self):
        code = wt.DWORD(0)
        return bool(self.h) and kernel32.GetExitCodeProcess(self.h, ctypes.byref(code)) and code.value == 259

    def read(self, addr, size):
        buf = ctypes.create_string_buffer(size)
        if not kernel32.ReadProcessMemory(self.h, ctypes.c_void_p(addr), buf, size, ctypes.byref(self._n)) or self._n.value != size:
            return None
        return buf.raw

    def read_into(self, addr, buf, size):
        return kernel32.ReadProcessMemory(self.h, ctypes.c_void_p(addr), buf, size, ctypes.byref(self._n)) and self._n.value == size

    def regions(self, max_addr=0xFFFF0000):     # 32 bits LAA: hasta 4 GB
        mbi, addr = MBI(), 0
        while addr < max_addr and kernel32.VirtualQueryEx(self.h, ctypes.c_void_p(addr), ctypes.byref(mbi), ctypes.sizeof(mbi)):
            if mbi.State == MEM_COMMIT and not (mbi.Protect & (PAGE_GUARD | PAGE_NOACCESS)) and mbi.Protect:
                yield mbi.BaseAddress, mbi.RegionSize, mbi.Protect, mbi.Type
            addr = mbi.BaseAddress + mbi.RegionSize

    def modules(self):
        snap = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, self.pid)
        out = []
        me = MODULEENTRY32W()
        me.dwSize = ctypes.sizeof(me)
        ok = kernel32.Module32FirstW(snap, ctypes.byref(me))
        while ok:
            out.append((me.szModule, me.modBaseAddr or 0, me.modBaseSize))
            ok = kernel32.Module32NextW(snap, ctypes.byref(me))
        kernel32.CloseHandle(snap)
        return out

    def module(self, name):
        name = name.lower()
        return next(((b, s) for n, b, s in self.modules() if n.lower() == name), (None, None))
