/*
 * vmtest.c — VM subsystem comprehensive test
 * Covers: COW / Stack expansion / Demand paging / Multi-process COW / Fork stress
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys.h>

#define PAGE 4096
#define PASS() printf("  [PASS]\n")
#define FAIL(msg) printf("  [FAIL] %s\n", msg)

/* === Test 1: COW === */
static char cow_buf[PAGE * 2] __attribute__((aligned(PAGE)));

int test_cow(void)
{
    int i, pid, status, errors = 0;
    printf("Test 1: COW (Copy-on-Write)\n");

    for (i = 0; i < PAGE; i++) cow_buf[i] = 'A';

    pid = fork();
    if (pid < 0) { FAIL("fork failed"); return 1; }

    if (pid == 0) {
        for (i = 0; i < PAGE / 2; i++) cow_buf[i] = 'B';
        for (i = 0; i < PAGE / 2; i++)
            if (cow_buf[i] != 'B') errors++;
        for (i = PAGE / 2; i < PAGE; i++)
            if (cow_buf[i] != 'A') errors++;
        exit(errors ? 1 : 0);
    }

    wait(&status);
    for (i = 0; i < PAGE; i++)
        if (cow_buf[i] != 'A') errors++;

    if (errors) FAIL("COW isolation broken");
    else PASS();
    return errors;
}

/* === Test 2: Stack auto-expansion (deep recursion) === */
static int stack_ok = 1;
static int max_depth = 0;
static char stack_test_pattern = 0;

static int do_recurse(int n)
{
    /* 每层 256 字节局部变量, 200 层 = ~50KB 栈 */
    volatile char frame[256];
    int i;
    for (i = 0; i < 256; i++) frame[i] = (char)(n & 0xFF);

    if (n > max_depth) max_depth = n;

    if (n > 0) {
        do_recurse(n - 1);
    }

    /* 返回时验证栈数据未被破坏 */
    for (i = 0; i < 256; i++)
        if (frame[i] != (char)(n & 0xFF)) stack_ok = 0;
    return stack_ok;
}

int test_stack(void)
{
    printf("Test 2: Stack auto-expansion (deep recursion)\n");

    stack_ok = 1;
    max_depth = 0;
    stack_test_pattern = 0;
    do_recurse(200);

    if (stack_ok) {
        printf("  max depth=%d\n", max_depth);
        PASS();
    } else {
        FAIL("stack data corrupted");
    }
    return stack_ok ? 0 : 1;
}

/* === Test 3: Demand paging === */
int test_demand(void)
{
    int i, errors = 0;
    printf("Test 3: Demand paging (heap 16 pages)\n");

    unsigned int old_end = sbrk(0);
    unsigned int new_end = sbrk(PAGE * 16);
    if (new_end == (unsigned int)-1) { FAIL("sbrk failed"); return 1; }

    unsigned char *p = (unsigned char *)old_end;
    for (i = 0; i < 16; i++) p[i * PAGE] = (unsigned char)(i + 1);
    for (i = 0; i < 16; i++)
        if (p[i * PAGE] != (unsigned char)(i + 1)) errors++;

    sbrk(- (int)(PAGE * 16));

    if (errors) FAIL("demand paging data mismatch");
    else PASS();
    return errors;
}

/* === Test 4: Multi-process COW === */
static char mcow_buf[PAGE] __attribute__((aligned(PAGE)));

int test_multi_cow(void)
{
    int i, pid1, pid2, status, errors = 0;
    printf("Test 4: Multi-process COW (3 processes)\n");

    for (i = 0; i < PAGE; i++) mcow_buf[i] = 'X';

    pid1 = fork();
    if (pid1 < 0) { FAIL("fork1 failed"); return 1; }

    if (pid1 == 0) {
        for (i = 0; i < PAGE / 3; i++) mcow_buf[i] = 'Y';
        pid2 = fork();
        if (pid2 < 0) exit(1);
        if (pid2 == 0) {
            for (i = PAGE / 3; i < PAGE * 2 / 3; i++) mcow_buf[i] = 'Z';
            for (i = 0; i < PAGE / 3; i++)
                if (mcow_buf[i] != 'Y') errors++;
            for (i = PAGE / 3; i < PAGE * 2 / 3; i++)
                if (mcow_buf[i] != 'Z') errors++;
            exit(errors ? 1 : 0);
        }
        wait(&status);
        for (i = 0; i < PAGE / 3; i++)
            if (mcow_buf[i] != 'Y') errors++;
        exit(errors ? 1 : 0);
    }

    wait(&status);
    for (i = 0; i < PAGE; i++)
        if (mcow_buf[i] != 'X') errors++;

    if (errors) FAIL("multi-COW isolation broken");
    else PASS();
    return errors;
}

/* === Test 5: Fork/exit stress === */
int test_fork_exit(void)
{
    int i, pid, status, errors = 0;
    printf("Test 5: Fork/exit stress (20 rounds)\n");

    for (i = 0; i < 20; i++) {
        pid = fork();
        if (pid < 0) { FAIL("fork failed in stress"); errors++; break; }
        if (pid == 0) exit(0);
        wait(&status);
    }

    if (!errors) PASS();
    return errors;
}

/* === Main === */
int main1(int argc, char *argv[])
{
    int total = 0, passed = 0, r;

    printf("\n=== VM Subsystem Test Suite ===\n\n");

    r = test_cow();       if (r == 0) passed++; total++;
    r = test_stack();     if (r == 0) passed++; total++;
    r = test_demand();    if (r == 0) passed++; total++;
    r = test_multi_cow(); if (r == 0) passed++; total++;
    r = test_fork_exit(); if (r == 0) passed++; total++;

    printf("\n=== Result: %d/%d tests passed ===\n", passed, total);
    if (passed == total)
        printf("VM subsystem: ALL GREEN\n");
    else
        printf("VM subsystem: %d FAILURE(S)\n", total - passed);

    return (passed == total) ? 0 : 1;
}
