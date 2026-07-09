with open('D:/Desktop/UNIX V6++V1/oos/src/interrupt/Exception.cpp', 'rb') as f:
    data = f.read()

# Replace corrupted else block (byte 9736 to next sigsegv:)
end = data.find(b'\r\nsigsegv:\r\n', 9736)
print(f'Block: 9736 to {end}')

new_block = (
    b'else\r\n'
    b'\t\t{\r\n'
    b'\t\t\t/* Hash miss: text should have been inserted during Exec */\r\n'
    b'\t\t\tDiagnose::Write("[VM] TextMiss! inode=0x%x fp=%d\\n",\r\n'
    b'\t\t\t (unsigned int)inode, filePage);\r\n'
    b'\t\t\tgoto sigsegv;\r\n'
    b'\t\t}\r\n'
)

data = data[:9736] + new_block + data[end:]

with open('D:/Desktop/UNIX V6++V1/oos/src/interrupt/Exception.cpp', 'wb') as f:
    f.write(data)

# Verify
with open('D:/Desktop/UNIX V6++V1/oos/src/interrupt/Exception.cpp', 'rb') as f:
    d = f.read()
assert b'\\n"' in d, 'Backslash-n not found!'
assert b'TextMiss' in d, 'TextMiss not found!'
assert b'goto sigsegv' in d, 'goto not found!'
print('OK')
