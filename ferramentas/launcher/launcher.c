/* AVANTIPACK.exe - so abre o AVANTIPACK (mostra a logo na pasta).
   O proprio exe pede permissao de administrador (manifesto). Depois:
   1) se existir core\AVANTIPACK.lnk, abre o menu numa janela NOVA usando as
      configuracoes desse atalho (fonte Consolas, tamanho, cores, icone),
      do mesmo jeito que o Explorer faz (STARTF_TITLEISLINKNAME). Assim a
      elevacao de administrador nao joga fora a fonte.
   2) senao, roda o core\AVANTIPACK.bat (que cria o atalho e reabre por ele)
   3) versoes antigas: AVANTIPACK.bat ao lado do exe                                  */
typedef unsigned short wchar;
typedef void *HANDLE;
#define WINAPI __stdcall
__declspec(dllimport) unsigned long WINAPI GetModuleFileNameW(HANDLE, wchar *, unsigned long);
__declspec(dllimport) unsigned long WINAPI GetFileAttributesW(const wchar *);
__declspec(dllimport) void WINAPI ExitProcess(unsigned int);
__declspec(dllimport) HANDLE WINAPI ShellExecuteW(HANDLE, const wchar *, const wchar *, const wchar *, const wchar *, int);
__declspec(dllimport) int WINAPI MessageBoxW(HANDLE, const wchar *, const wchar *, unsigned int);
typedef struct {
    unsigned long cb; wchar *lpReserved; wchar *lpDesktop; wchar *lpTitle;
    unsigned long dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    unsigned short wShowWindow, cbReserved2; unsigned char *lpReserved2;
    HANDLE hStdInput, hStdOutput, hStdError;
} STARTUPINFOW;
typedef struct { HANDLE hProcess, hThread; unsigned long dwProcessId, dwThreadId; } PROCESS_INFORMATION;
__declspec(dllimport) int WINAPI CreateProcessW(const wchar *, wchar *, void *, void *, int, unsigned long, void *, const wchar *, STARTUPINFOW *, PROCESS_INFORMATION *);
__declspec(dllimport) int WINAPI CloseHandle(HANDLE);
#define STARTF_TITLEISLINKNAME 0x00000800
#define CREATE_NEW_CONSOLE     0x00000010

void *memset(void *d, int c, unsigned long long n) { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *memcpy(void *d, const void *s, unsigned long long n) { unsigned char *a = d; const unsigned char *b = s; while (n--) *a++ = *b++; return d; }

static int cat(wchar *dst, int pos, int max, const wchar *src) {
    while (*src && pos < max - 1) dst[pos++] = *src++;
    dst[pos] = 0; return pos;
}
#define INVALID 0xFFFFFFFFul

void Main(void) {
    static wchar dir[600], lnk[700], bat[700], args[760];   /* fora da pilha */
    unsigned long n = GetModuleFileNameW(0, dir, 600);
    int i = (int)n;
    while (i > 0 && dir[i - 1] != L'\\') i--;
    dir[i] = 0;                                   /* "C:\...\AVANTIPACK\" */
    int p = cat(lnk, 0, 700, dir); cat(lnk, p, 700, L"core\\AVANTIPACK.lnk");
    p = cat(bat, 0, 700, dir); cat(bat, p, 700, L"core\\AVANTIPACK.bat");
    if (GetFileAttributesW(bat) == INVALID) { p = cat(bat, 0, 700, dir); cat(bat, p, 700, L"AVANTIPACK.bat"); }
    if (GetFileAttributesW(lnk) != INVALID && GetFileAttributesW(bat) != INVALID) {
        /* cmd.exe /c ""...\core\AVANTIPACK.bat" lnk"  numa janela nova com as configs do atalho */
        static STARTUPINFOW si; static PROCESS_INFORMATION pi;
        p = cat(args, 0, 760, L"cmd.exe /c \"\""); p = cat(args, p, 760, bat); cat(args, p, 760, L"\" lnk\"");
        si.cb = sizeof(si); si.lpTitle = lnk; si.dwFlags = STARTF_TITLEISLINKNAME;
        if (CreateProcessW(0, args, 0, 0, 0, CREATE_NEW_CONSOLE, 0, dir, &si, &pi)) {
            CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        } else {
            ShellExecuteW(0, L"open", lnk, 0, dir, 1);      /* plano B */
        }
    } else if (GetFileAttributesW(lnk) != INVALID) {
        ShellExecuteW(0, L"open", lnk, 0, dir, 1);
    } else if (GetFileAttributesW(bat) != INVALID) {
        p = cat(args, 0, 760, L"/c \"\""); p = cat(args, p, 760, bat); cat(args, p, 760, L"\"\"");
        ShellExecuteW(0, L"open", L"cmd.exe", args, dir, 1);
    } else {
        MessageBoxW(0, L"Nao achei a pasta core do AVANTIPACK.\nExtraia o pack inteiro (todas as pastas) antes de abrir.", L"AVANTIPACK", 0x30);
    }
    ExitProcess(0);
}
