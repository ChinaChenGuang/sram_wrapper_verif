// ============================================================
// vcsuser.h — Minimal VCS header stubs for Verilator
// ============================================================
#ifndef VCSUSER_H
#define VCSUSER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// --- PLI/VPI types ---
typedef uint32_t PLI_INT32;
typedef uint32_t PLI_UINT32;
typedef void*    PLI_BYTE8;

typedef struct t_vpi_handle* vpiHandle;

typedef struct t_vpi_value {
    int format;
    union {
        char *str;
        int scalar;
        double real;
        struct t_vpi_vecval *vector;
    } value;
} s_vpi_value, *p_vpi_value;

// --- ACC types ---
typedef void* handle;

#define accNet       1
#define accReg       2
#define accModule    3
#define accScope     4
#define accPort      5
#define accNetBit    6

// --- VPI types ---
#define vpiNet       1
#define vpiModule    2
#define vpiPort      3
#define vpiReg       4
#define vpiIntegerVar 5
#define vpiRealVar   6
#define vpiTimeVar   7
#define vpiNamedEvent 8

#define vpiFullName  1
#define vpiName      2
#define vpiSize      3
#define vpiType      4
#define vpiDefName   5

#define vpiIntVal     1
#define vpiStringVal  2
#define vpiDecStrVal  3
#define vpiHexStrVal  4
#define vpiBinStrVal  5
#define vpiOctStrVal  6
#define vpiRealVal    7
#define vpiVectorVal  8

#define vpiNoDelay    1
#define vpiInertialDelay 2

#define vpiSuppressTime 1
#define vpiSuppressGlitch 2

// --- VCS-specific ---
#define accCell      10
#define accSeqUdp    11
#define accCombUdp   12

typedef struct t_vecval {
    int aval;
    int bval;
} s_vecval, *p_vecval;

typedef struct s_vpi_time {
    int type;
    uint32_t high, low;
    double real;
} s_vpi_time, *p_vpi_time;

// --- Function declarations ---
handle acc_handle_by_name(const char *name, void *scope);
int    acc_fetch_fullname(handle obj, char *buf, int sz);
int    acc_fetch_name(handle obj, char *buf, int sz);
int    acc_object_of_type(handle obj, int type);
int    acc_fetch_size(handle obj);
int    acc_fetch_index(handle obj);
int    acc_fetch_range(handle obj, int *msb, int *lsb);
handle acc_next_cell(handle net, handle ref);
handle acc_next_net(handle ref);
handle acc_next_scope(handle ref);
handle acc_handle_scope(handle obj);
handle acc_next_child(handle mod, handle child);
void   acc_close(handle obj);
void   acc_initialize(void);
int    acc_fetch_paramval(handle obj, char *buf, int sz);
void   acc_configure(int a, int b);

char*  tf_getcstringp(int n);
int    tf_getp(int n);
int    tf_nump(void);
int    tf_getlongp(int *a, int n);
void   tf_putp(int n, int v);
void   tf_setworkarea(void *p);
void*  tf_getworkarea(void);

vpiHandle vpi_handle_by_name(const char *name, vpiHandle scope);
vpiHandle vpi_iterate(int type, vpiHandle ref);
vpiHandle vpi_scan(vpiHandle iter);
vpiHandle vpi_handle(int type, vpiHandle ref);
char*     vpi_get_str(int prop, vpiHandle obj);
int       vpi_get(int prop, vpiHandle obj);
void      vpi_get_value(vpiHandle obj, p_vpi_value val);
vpiHandle vpi_put_value(vpiHandle obj, p_vpi_value val, void *when, int flags);
void      vpi_free_object(vpiHandle obj);
int       vpi_get_vlog_info(void *info);
int       vpi_chk_error(vpiHandle *err);
int       vpi_mcd_close(int mcd);
char*     vpi_mcd_name(int mcd);
int       vpi_mcd_open(char *name);
int       vpi_mcd_printf(int mcd, char *fmt, ...);
int       vpi_printf(char *fmt, ...);
void      vpi_get_time(vpiHandle obj, void *time);

// VCS helpers
int snPrintAttrs(char *buf, int sz, int nargs, ...);
int tf_dofinish(void);
int vcs_execution_region(void);

// time type for VCS
typedef struct s_vcs_time { int type; uint32_t h,l; double r; } s_vcs_time;

#ifdef __cplusplus
}
#endif

#endif // VCSUSER_H
