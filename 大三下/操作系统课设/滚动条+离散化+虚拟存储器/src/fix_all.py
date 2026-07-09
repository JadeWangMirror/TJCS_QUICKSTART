"""Apply minimal VM fixes to oos/src without hash table or text demand paging."""

import os, shutil

SRC = 'D:/Desktop/UNIX V6++V1/oos/src'
BAK = 'D:/Desktop/UNIX V6++V1/85分基础版本/src'

files_to_restore = [
    'include/Kernel.h',
    'include/Kernel.cpp.orig',  # will handle specially
    'include/MemoryDescriptor.h',
    'include/Utility.h',
    'proc/MemoryDescriptor.cpp',
    'proc/Process.cpp',
    'proc/ProcessManager.cpp',
    'mm/Makefile',
]
# Actually let me just copy key files from 85分 that I need to restore
to_restore = [
    'include/Kernel.h',
    'include/MemoryDescriptor.h',
    'include/Utility.h',
    'proc/MemoryDescriptor.cpp',
    'proc/Process.cpp',
    'proc/ProcessManager.cpp',
    'kernel/Kernel.cpp',
    'kernel/Utility.cpp',
    'interrupt/Exception.cpp',
    'mm/Makefile',
    'mm/PageManager.cpp',
]
print('Restoring from 85分...')
for f in to_restore:
    src = os.path.join(BAK, f)
    dst = os.path.join(SRC, f)
    shutil.copy2(src, dst)
    print(f'  {f}')

print('All restored to 85分 original.')
