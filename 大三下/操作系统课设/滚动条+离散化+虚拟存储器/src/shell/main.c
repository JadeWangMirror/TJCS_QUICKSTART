#include "stdio.h"
#include "stdlib.h"
#include "sys.h"
#include "file.h"

#include "CommandTree.h"
#include "ExecuteCommand.h"
#include "globe.h"
#include "PreExecute.h"
#include "string.h"

char line[1000];
char* args[50];
int argsCnt;

#define HISTORY_MAX 20
char history[HISTORY_MAX][512];
int history_count = 0;
int history_pos = 0;

void clear_line(int len) {
    int i;
    for (i = 0; i < len; i++) write(1, "\b \b", 3);
}

struct DirectoryEntry {
	int m_ino;
	char m_name[28];
};

int my_strncmp(const char *s1, const char *s2, int n) {
    int i;
    for (i = 0; i < n; i++) {
        if (s1[i] != s2[i]) return s1[i] - s2[i];
        if (s1[i] == 0) return 0;
    }
    return 0;
}

void my_strncpy(char *dest, const char *src, int n) {
    int i;
    for (i = 0; i < n && src[i] != 0; i++) dest[i] = src[i];
    for (; i < n; i++) dest[i] = 0;
}

char* my_strrchr(const char *s, int c) {
    const char *last = 0;
    while (*s) {
        if (*s == c) last = s;
        s++;
    }
    return (char*)last;
}

void do_completion(char* currentInput, int* len) {
    char lastWord[100];
    int i, j;
    int wordStart = *len;

    while (wordStart > 0 && currentInput[wordStart-1] != ' ')
        wordStart--;

    int wordLen = 0;
    for (i = wordStart; i < *len; i++) {
        if (wordLen < 99) lastWord[wordLen++] = currentInput[i];
    }
    lastWord[wordLen] = 0;
    if (wordLen == 0) return;

    static char matches[100][64];
    int matchCount = 0;

    int isCommand = (wordStart == 0);
    if (isCommand) {
        const char* builtins[] = { "cd", "exit", "help", "history" };
        int numBuiltins = 4;
        for (i = 0; i < numBuiltins; i++) {
            if (my_strncmp(builtins[i], lastWord, wordLen) == 0)
                if (matchCount < 100) strcpy(matches[matchCount++], builtins[i]);
        }
        int binFd = open("/bin", 1);
        if (binFd >= 0) {
            struct DirectoryEntry de;
            while (read(binFd, &de, 32) > 0) {
                if (de.m_ino == 0) continue;
                if (my_strncmp(de.m_name, lastWord, wordLen) == 0) {
                    int exists = 0, k;
                    for (k = 0; k < matchCount; k++)
                        if (strcmp(matches[k], de.m_name) == 0) { exists = 1; break; }
                    if (!exists && matchCount < 100) strcpy(matches[matchCount++], de.m_name);
                }
            }
            close(binFd);
        }
    }

    char searchDir[100], filePrefix[100];
    char* lastSlash = my_strrchr(lastWord, '/');
    if (lastSlash) {
        int dirLen = lastSlash - lastWord + 1;
        my_strncpy(searchDir, lastWord, dirLen);
        searchDir[dirLen] = 0;
        strcpy(filePrefix, lastSlash + 1);
    } else {
        strcpy(searchDir, ".");
        strcpy(filePrefix, lastWord);
    }

    int fd = open(searchDir, 1);
    if (fd >= 0) {
        struct DirectoryEntry de;
        while (read(fd, &de, 32) > 0) {
            if (de.m_ino == 0) continue;
            if (my_strncmp(de.m_name, filePrefix, strlen(filePrefix)) == 0) {
                int exists = 0, k;
                for (k = 0; k < matchCount; k++)
                    if (strcmp(matches[k], de.m_name) == 0) { exists = 1; break; }
                if (!exists && matchCount < 100) strcpy(matches[matchCount++], de.m_name);
            }
        }
        close(fd);
    }

    if (matchCount == 0) return;

    char lcp[64];
    strcpy(lcp, matches[0]);
    for (i = 1; i < matchCount; i++) {
        j = 0;
        while (lcp[j] && matches[i][j] && lcp[j] == matches[i][j]) j++;
        lcp[j] = 0;
    }

    if (matchCount == 1) {
        char fullPath[100];
        if (lastSlash) {
            strcpy(fullPath, searchDir);
            strcat(fullPath, matches[0]);
        } else {
            strcpy(fullPath, strcmp(searchDir, ".") == 0 ? "" : searchDir);
            if (strcmp(searchDir, ".") != 0) strcat(fullPath, "/");
            strcat(fullPath, matches[0]);
        }
        struct st_inode inode;
        int isDir = 0;
        if (stat(fullPath, &inode) == 0) {
            if ((inode.st_mode & 0x4000) != 0) isDir = 1;
        }
        strcat(lcp, isDir ? "/" : " ");
    }

    int prefixLen = strlen(filePrefix);
    int lcpLen = strlen(lcp);
    for (j = prefixLen; j < lcpLen; j++) {
        if (*len < 511) {
            currentInput[*len] = lcp[j];
            (*len)++;
            write(1, &lcp[j], 1);
        }
    }
}

int main1()
{
	char lineInput[512];
    char currentInput[512];
    int currentLen = 0;
	getPath(curPath);
	int root, i;

    for (i = 0; i < HISTORY_MAX; i++) history[i][0] = 0;

	while (1)
	{
		root = -1;
		argsCnt = 0;
		InitCommandTree();
		printf("[%s]#", curPath);

        currentLen = 0;
        currentInput[0] = 0;
        history_pos = history_count;

        while (1) {
            char buf[512];
            int n = read(0, buf, 512);
            if (n <= 0) continue;

            int k;
            for (k = 0; k < n; k++) {
                char c = buf[k];

                if (c == 0x08 || c == 0x7F) {
                    if (currentLen > 0) {
                        currentLen--;
                        currentInput[currentLen] = 0;
                        write(1, "\b \b", 3);
                    }
                    continue;
                }
                if (c == '\n' || c == '\r') goto execute_command;
                if (c == 0x09) {
                    do_completion(currentInput, &currentLen);
                    continue;
                }
                if (c == 0x13 || c == 0x17) {
                    clear_line(currentLen);
                    if (c == 0x17) { if (history_pos > 0) history_pos--; }
                    else           { if (history_pos < history_count) history_pos++; }
                    if (history_pos < history_count)
                        strcpy(currentInput, history[history_pos % HISTORY_MAX]);
                    else
                        currentInput[0] = 0;
                    write(1, currentInput, strlen(currentInput));
                    currentLen = strlen(currentInput);
                    continue;
                }
                if (currentLen < 511) {
                    currentInput[currentLen++] = c;
                    currentInput[currentLen] = 0;
                }
            }
        }

        execute_command:
        strcpy(lineInput, currentInput);

        if (strlen(lineInput) > 0) {
            strcpy(history[history_count % HISTORY_MAX], lineInput);
            history_count++;
        }

		if (strcmp("shutdown", lineInput) == 0)
		{
			syncFileSystem();
			printf("You can safely turn down the computer now!\n");
			break;
		}
		argsCnt = SpiltCommand(lineInput);
		root = AnalizeCommand(0, argsCnt - 1, 0);
		if (root >= 0)
			ExecuteCommand(&commandNodes[root], 0, 0);
	}
	return 0;
}
