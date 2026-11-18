/* AVANTIPACK.exe - so abre o AVANTIPACK (mostra a logo na pasta).
   1) se existir core\AVANTIPACK.lnk, abre ele (janela bonita, como administrador)
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
    if (GetFileAttributesW(lnk) != INVALID) {
        ShellExecuteW(0, L"open", lnk, 0, dir, 1);
    } else if (GetFileAttributesW(bat) != INVALID) {
        p = cat(args, 0, 760, L"/c \"\""); p = cat(args, p, 760, bat); cat(args, p, 760, L"\"\"");
        ShellExecuteW(0, L"open", L"cmd.exe", args, dir, 1);
    } else {
        MessageBoxW(0, L"Nao achei a pasta core do AVANTIPACK.\nExtraia o pack inteiro (todas as pastas) antes de abrir.", L"AVANTIPACK", 0x30);
    }
    ExitProcess(0);
}
