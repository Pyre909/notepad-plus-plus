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
