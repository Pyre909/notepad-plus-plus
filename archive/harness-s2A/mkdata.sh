#!/bin/sh
# mkdata.sh: test data for the panels (FaW folder, Project Panel workspace, C++ sample for the Function List)
H=$(cd "$(dirname "$0")" && pwd)
D=$H/data
rm -rf "$D"
mkdir -p "$D/ws/src/lib" "$D/ws/docs" "$D/ws/tests"
printf 'int main() { return 0; }\r\n' > "$D/ws/src/main.cpp"
printf '#pragma once\r\nint util();\r\n' > "$D/ws/src/util.h"
printf 'int lib() { return 1; }\r\n' > "$D/ws/src/lib/lib.cpp"
printf '# docs\r\n' > "$D/ws/docs/readme.md"
printf 'guide\r\n' > "$D/ws/docs/guide.txt"
printf 'test\r\n' > "$D/ws/tests/test1.cpp"
printf 'notes\r\n' > "$D/ws/notes.txt"
printf '@echo off\r\n' > "$D/ws/build.bat"
cat > "$D/sample.cpp" <<'EOF'
// sample for the Function List
#include <cstdio>

namespace demo
{
	class Shape
	{
	public:
		virtual double area() const { return 0; }
		virtual const char* name() const { return "shape"; }
	};

	class Circle : public Shape
	{
	public:
		double area() const override { return 3.14159 * _r * _r; }
		const char* name() const override { return "circle"; }
	private:
		double _r = 1.0;
	};
}

static int add(int a, int b)
{
	return a + b;
}

static void printTotal(int total)
{
	printf("%d\n", total);
}

int main(int argc, char** argv)
{
	printTotal(add(argc, 1));
	return 0;
}
EOF
WIN=$(printf 'Z:%s' "$D" | sed 's#/#\\#g')
cat > "$D/demo.workspace" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus>
    <Project name="Demo project">
        <Folder name="src">
            <File name="$WIN\\ws\\src\\main.cpp" />
            <File name="$WIN\\ws\\src\\util.h" />
            <Folder name="lib">
                <File name="$WIN\\ws\\src\\lib\\lib.cpp" />
            </Folder>
        </Folder>
        <Folder name="docs">
            <File name="$WIN\\ws\\docs\\readme.md" />
            <File name="$WIN\\ws\\docs\\missing.txt" />
        </Folder>
        <File name="$WIN\\sample.cpp" />
    </Project>
    <Project name="Second project">
        <File name="$WIN\\ws\\notes.txt" />
    </Project>
</NotepadPlus>
EOF
find "$D" | sort
