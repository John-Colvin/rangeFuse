static import std.concurrency;

template fuse(alias alg0, alias alg1)
{
	auto fuse(R)(R range)
	{
		import std.typecons : scoped, tuple;
		import std.range : refRange;

		auto tmp = ControlledRange!(R, 2)(range);
		auto controlled = refRange(&tmp);

		auto scheduler = scoped!(std.concurrency.FiberScheduler);

		typeof(alg0(controlled)) res0;
		typeof(alg1(controlled)) res1;

		scheduler.spawn(() { res0 = alg0(controlled); });
		scheduler.start(() { res1 = alg1(controlled); });

		return tuple(res0, res1);
	}
}

unittest
{
	import std.algorithm;
	import std.range;
	import std.stdio;
    import std.typecons;

	auto a = iota(1, 7);
	auto res = a.fuse!(reduce!"a + b", reduce!"a * b");
    assert (res == tuple(21, 720));
}

private struct ControlledRange(R, uint popsPerPop)
{
	static assert (popsPerPop != 0);

	R r;
	uint nPops = 0;

	this(R r) { this.r = r; }
	auto front() @property { return r.front; }
	bool empty() @property { return r.empty; }
	void popFront()
	{
		++nPops;
		if (nPops == popsPerPop)
		{
			r.popFront();
			nPops = 0;
		}
		std.concurrency.yield();
	}
}
