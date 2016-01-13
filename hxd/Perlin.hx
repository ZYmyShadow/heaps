package hxd;

class Perlin {

	public var repeat : Int;
	#if flash
	var buf : flash.utils.ByteArray;
	#else
	var gradients : Array<Float>;
	#end

	public function new() {
		repeat = 0x7FFFFFFF;
		#if flash
		// space for gradients
		buf = new flash.utils.ByteArray();
		buf.length += NGRADS * 4 * 8;
		// init gradients and alpha channel
		flash.Memory.select(buf);
		for( i in 0...NGRADS ) {
			var p = i << 5;
			setDouble(p, GRADIENTS[i * 3] * 2.12);
			setDouble(p + 8, GRADIENTS[i * 3 + 1] * 2.12);
			setDouble(p + 16, GRADIENTS[i * 3 + 2] * 2.12);
			setDouble(p + 24, 0); // padding
		}
		#else
		gradients = [];
		for( i in 0...NGRADS ) {
			gradients.push(GRADIENTS[i * 3] * 2.12);
			gradients.push(GRADIENTS[i * 3 + 1] * 2.12);
			gradients.push(GRADIENTS[i * 3 + 2] * 2.12);
			gradients.push(0); // padding
		}
		#end
		select();
	}

	public inline function select() {
		#if flash
		flash.Memory.select(buf);
		#end
	}

	#if flash
	inline function setDouble( index : Int, v : Float )  {
		flash.Memory.setDouble(index, v);
	}

	inline function double( index : Int ) : Float {
		return flash.Memory.getDouble(index);

	}
	#end

	inline function scurve( a : Float ) {
		var a2 = a * a;
		return a2 * a * (6.0 * a2 - 15.0 * a + 10.0);
	}

	inline function linear( a : Float, b : Float, k : Float ) : Float {
		return a + k * (b  - a);
	}

	inline function gradient3DAt( x : Float, y : Float, z : Float, ix : Int, iy : Int, iz : Int, seed : Int ) {
		var index = seed * 1013 + (ix % repeat) * 1619 + (iy % repeat) * 31337 + iz * 6971;
		index = ((index ^ (index >>> 8)) & 0xFF);
		#if flash
		index <<= 5;
		var gx = double(index);
		var gy = double(index + 8);
		var gz = double(index + 16);
		#else
		index <<= 2;
		var gx = gradients[index];
		var gy = gradients[index + 1];
		var gz = gradients[index + 2];
		#end
		return gx * (x - ix) + gy * (y - iy) + gz * (z - iz);
	}

	inline function gradientAt( x : Float, y : Float, ix : Int, iy : Int, seed : Int ) {
		var index = seed * 1013 + (ix%repeat) * 1619 + (iy%repeat) * 31337;
		index = ((index ^ (index >>> 8)) & 0xFF);
		#if flash
		index <<= 5;
		var gx = double(index);
		var gy = double(index + 8);
		#else
		var gx = gradients[index << 2];
		var gy = gradients[(index << 2) + 1];
		#end
		return gx * (x - ix) + gy * (y - iy);
	}

	public function adjustScale( size : Int, scale : Float ) {
		repeat = Std.int(size * scale);
		return repeat / size;
	}

	public function gradient3D( seed : Int, x : Float, y : Float, z : Float ) {
		var ix = Std.int(x), xs = scurve(x - ix);
		var iy = Std.int(y), ys = scurve(y - iy);
		var iz = Std.int(z), zs = scurve(z - iz);

		var ga = gradient3DAt(x, y, z, ix, iy, iz, seed);
		var gb = gradient3DAt(x, y, z, ix + 1, iy, iz, seed);
		var gc = gradient3DAt(x, y, z, ix, iy + 1, iz, seed);
		var gd = gradient3DAt(x, y, z, ix + 1, iy + 1, iz, seed);
		var v1 = linear(linear(ga, gb, xs), linear(gc, gd, xs), ys);

		var ga = gradient3DAt(x, y, z, ix, iy, iz + 1, seed);
		var gb = gradient3DAt(x, y, z, ix + 1, iy, iz + 1, seed);
		var gc = gradient3DAt(x, y, z, ix, iy + 1, iz + 1, seed);
		var gd = gradient3DAt(x, y, z, ix + 1, iy + 1, iz + 1, seed);
		var v2 = linear(linear(ga, gb, xs), linear(gc, gd, xs), ys);

		return linear(v1, v2, zs);
	}

	public function gradient( seed : Int, x : Float, y : Float ) {
		return inlineGradient(seed, x, y);
	}

	public inline function inlineGradient( seed : Int, x : Float, y : Float ) {
		var ix = Std.int(x), xs = scurve(x - ix);
		var iy = Std.int(y), ys = scurve(y - iy);
		var ga = gradientAt(x, y, ix, iy, seed);
		var gb = gradientAt(x, y, ix + 1, iy, seed);
		var gc = gradientAt(x, y, ix, iy + 1, seed);
		var gd = gradientAt(x, y, ix + 1, iy + 1, seed);
		return linear(linear(ga, gb, xs), linear(gc, gd, xs), ys);
	}

	public function perlin( seed : Int, x : Float, y : Float, octaves : Int, persist : Float = 0.5, lacunarity = 2.0 ) {
		var v = 0.;
		var k = 1.;
		for( i in 0...octaves ) {
			v += inlineGradient(seed + i, x, y) * k;
			k *= persist;
			x *= lacunarity;
			y *= lacunarity;
		}
		return v;
	}

	public function ridged( seed : Int, x : Float, y : Float, octaves : Int, offset : Float = 0.5, gain : Float = 2.0, persist : Float = 0.5, lacunarity = 2.0 ) {
		var v = 0.;
		var p = 1.;
		var s = lacunarity;
		var weight = 1.;
		var tot = 0.;
		for( i in 0...octaves ) {
			var g = inlineGradient(seed + i, x * s, y * s) * p;
			g = offset - hxd.Math.abs(g);
			g *= g;
			g *= weight;
			v += g * s;
			tot += p;
			weight = g * gain;
			if( weight < 0 ) weight = 0 else if( weight > 1 ) weight = 1;
			p *= persist;
			s *= lacunarity;
		}
		return v / tot;
	}

	/**
		Converts a desired probability in the [0,1] range into the corresponding perlin value that we must test against for threshold.
	**/
	public function thresholdValue( p : Float ) {
		if( p < 0 ) p = 0 else if( p > 1 ) p = 1;
		p *= 100;
		var ip = Std.int(p);
		var rp = p - ip;
		return THRESHOLD[ip] * (1 - rp) + THRESHOLD[ip + 1] * rp;
	}

	public function maxValue( octaves : Int, persist : Float ) {
		var tot = 0.;
		var n = 1.;
		for( i in 0...octaves ) {
			tot += n;
			n *= persist;
		}
		return tot;
	}

	// calculated by taking random samples
	static var THRESHOLD = [1, 0.8592513390087628, 0.7688052643570193, 0.7087726039952893, 0.6647113603276184, 0.6259580701471196, 0.5920876252486609, 0.5638284687296424, 0.5369372345528312, 0.511056830054494, 0.4891529471303026, 0.4686450546837182, 0.4469326426188986, 0.42882977072465217, 0.4115690486935469, 0.3952190621773927, 0.3798495121020824, 0.3643113031451191, 0.35076791715497774, 0.3358660685112593, 0.32201072855694396, 0.30892806298001424, 0.29560958280721134, 0.2832470678288159, 0.2722624402634705, 0.2600091343032725, 0.24710140949920625, 0.2349447759632499, 0.22457445993513606, 0.2131403744385778, 0.20134549348263955, 0.19132099693471735, 0.18016204676639877, 0.16909697184035943, 0.15815708577407128, 0.14775905113977691, 0.13737312582001757, 0.12679718647885954, 0.11701991502195597, 0.10624599158763885, 0.09609048359894327, 0.08635324413900251, 0.0762801324162865, 0.06646726089820731, 0.0571162548765321, 0.04732040978140301, 0.03746852290171843, 0.02760801110707689, 0.01855811300246339, 0.008752118293491621, -0.00026550350742319883, -0.009223060038956728, -0.018789261222506563, -0.02813411229450641, -0.037449134344404396, -0.047633978239489054, -0.05667766384393364, -0.06659034350322503, -0.07645132312609348, -0.08656692974909674, -0.09627118700050882, -0.1064336189892197, -0.11629659915342927, -0.12724141562978428, -0.1365750929947163, -0.14749015429008164, -0.15794701447299161, -0.1690704979682489, -0.1797491149113014, -0.19011257230921322, -0.20267749998580525, -0.21336778447921598, -0.22415851131081582, -0.23631096442472443, -0.24807216374333516, -0.2591033223085105, -0.27269322302966537, -0.28403803141897216, -0.2963974007554812, -0.3083788633812219, -0.32389260486288124, -0.33610722830796497, -0.3494739103345917, -0.3645474951406685, -0.3788771169950788, -0.3946810512888161, -0.41116590125178826, -0.42801184970580164, -0.44724281354749623, -0.4675222546982302, -0.4879511602870796, -0.5116520577174579, -0.5363099352376801, -0.5631265791839567, -0.5916916949583626, -0.6247612900993957, -0.6641509690983356, -0.7069660117262387, -0.7690351018175968, -0.8566093984511503, -1, -1];

	// 256 randomized 3D gradients
	static inline var NGRADS = 256;
	static inline var GPREC = 65536;
	static var GRADIENTS = [
		-0.763874, -0.596439, -0.246489,
		0.396055, 0.904518, -0.158073,
		-0.499004, -0.8665, -0.0131631,
		0.468724, -0.824756, 0.316346,
		0.829598, 0.43195, 0.353816,
		-0.454473, 0.629497, -0.630228,
		-0.162349, -0.869962, -0.465628,
		0.932805, 0.253451, 0.256198,
		-0.345419, 0.927299, -0.144227,
		-0.715026, -0.293698, -0.634413,
		-0.245997, 0.717467, -0.651711,
		-0.967409, -0.250435, -0.037451,
		0.901729, 0.397108, -0.170852,
		0.892657, -0.0720622, -0.444938,
		0.0260084, -0.0361701, 0.999007,
		0.949107, -0.19486, 0.247439,
		0.471803, -0.807064, -0.355036,
		0.879737, 0.141845, 0.453809,
		0.570747, 0.696415, 0.435033,
		-0.141751, -0.988233, -0.0574584,
		-0.58219, -0.0303005, 0.812488,
		-0.60922, 0.239482, -0.755975,
		0.299394, -0.197066, -0.933557,
		-0.851615, -0.220702, -0.47544,
		0.848886, 0.341829, -0.403169,
		-0.156129, -0.687241, 0.709453,
		-0.665651, 0.626724, 0.405124,
		0.595914, -0.674582, 0.43569,
		0.171025, -0.509292, 0.843428,
		0.78605, 0.536414, -0.307222,
		0.18905, -0.791613, 0.581042,
		-0.294916, 0.844994, 0.446105,
		0.342031, -0.58736, -0.7335,
		0.57155, 0.7869, 0.232635,
		0.885026, -0.408223, 0.223791,
		-0.789518, 0.571645, 0.223347,
		0.774571, 0.31566, 0.548087,
		-0.79695, -0.0433603, -0.602487,
		-0.142425, -0.473249, -0.869339,
		-0.0698838, 0.170442, 0.982886,
		0.687815, -0.484748, 0.540306,
		0.543703, -0.534446, -0.647112,
		0.97186, 0.184391, -0.146588,
		0.707084, 0.485713, -0.513921,
		0.942302, 0.331945, 0.043348,
		0.499084, 0.599922, 0.625307,
		-0.289203, 0.211107, 0.9337,
		0.412433, -0.71667, -0.56239,
		0.87721, -0.082816, 0.47291,
		-0.420685, -0.214278, 0.881538,
		0.752558, -0.0391579, 0.657361,
		0.0765725, -0.996789, 0.0234082,
		-0.544312, -0.309435, -0.779727,
		-0.455358, -0.415572, 0.787368,
		-0.874586, 0.483746, 0.0330131,
		0.245172, -0.0838623, 0.965846,
		0.382293, -0.432813, 0.81641,
		-0.287735, -0.905514, 0.311853,
		-0.667704, 0.704955, -0.239186,
		0.717885, -0.464002, -0.518983,
		0.976342, -0.214895, 0.0240053,
		-0.0733096, -0.921136, 0.382276,
		-0.986284, 0.151224, -0.0661379,
		-0.899319, -0.429671, 0.0812908,
		0.652102, -0.724625, 0.222893,
		0.203761, 0.458023, -0.865272,
		-0.030396, 0.698724, -0.714745,
		-0.460232, 0.839138, 0.289887,
		-0.0898602, 0.837894, 0.538386,
		-0.731595, 0.0793784, 0.677102,
		-0.447236, -0.788397, 0.422386,
		0.186481, 0.645855, -0.740335,
		-0.259006, 0.935463, 0.240467,
		0.445839, 0.819655, -0.359712,
		0.349962, 0.755022, -0.554499,
		-0.997078, -0.0359577, 0.0673977,
		-0.431163, -0.147516, -0.890133,
		0.299648, -0.63914, 0.708316,
		0.397043, 0.566526, -0.722084,
		-0.502489, 0.438308, -0.745246,
		0.0687235, 0.354097, 0.93268,
		-0.0476651, -0.462597, 0.885286,
		-0.221934, 0.900739, -0.373383,
		-0.956107, -0.225676, 0.186893,
		-0.187627, 0.391487, -0.900852,
		-0.224209, -0.315405, 0.92209,
		-0.730807, -0.537068, 0.421283,
		-0.0353135, -0.816748, 0.575913,
		-0.941391, 0.176991, -0.287153,
		-0.154174, 0.390458, 0.90762,
		-0.283847, 0.533842, 0.796519,
		-0.482737, -0.850448, 0.209052,
		-0.649175, 0.477748, 0.591886,
		0.885373, -0.405387, -0.227543,
		-0.147261, 0.181623, -0.972279,
		0.0959236, -0.115847, -0.988624,
		-0.89724, -0.191348, 0.397928,
		0.903553, -0.428461, -0.00350461,
		0.849072, -0.295807, -0.437693,
		0.65551, 0.741754, -0.141804,
		0.61598, -0.178669, 0.767232,
		0.0112967, 0.932256, -0.361623,
		-0.793031, 0.258012, 0.551845,
		0.421933, 0.454311, 0.784585,
		-0.319993, 0.0401618, -0.946568,
		-0.81571, 0.551307, -0.175151,
		-0.377644, 0.00322313, 0.925945,
		0.129759, -0.666581, -0.734052,
		0.601901, -0.654237, -0.457919,
		-0.927463, -0.0343576, -0.372334,
		-0.438663, -0.868301, -0.231578,
		-0.648845, -0.749138, -0.133387,
		0.507393, -0.588294, 0.629653,
		0.726958, 0.623665, 0.287358,
		0.411159, 0.367614, -0.834151,
		0.806333, 0.585117, -0.0864016,
		0.263935, -0.880876, 0.392932,
		0.421546, -0.201336, 0.884174,
		-0.683198, -0.569557, -0.456996,
		-0.117116, -0.0406654, -0.992285,
		-0.643679, -0.109196, -0.757465,
		-0.561559, -0.62989, 0.536554,
		0.0628422, 0.104677, -0.992519,
		0.480759, -0.2867, -0.828658,
		-0.228559, -0.228965, -0.946222,
		-0.10194, -0.65706, -0.746914,
		0.0689193, -0.678236, 0.731605,
		0.401019, -0.754026, 0.52022,
		-0.742141, 0.547083, -0.387203,
		-0.00210603, -0.796417, -0.604745,
		0.296725, -0.409909, -0.862513,
		-0.260932, -0.798201, 0.542945,
		-0.641628, 0.742379, 0.192838,
		-0.186009, -0.101514, 0.97729,
		0.106711, -0.962067, 0.251079,
		-0.743499, 0.30988, -0.592607,
		-0.795853, -0.605066, -0.0226607,
		-0.828661, -0.419471, -0.370628,
		0.0847218, -0.489815, -0.8677,
		-0.381405, 0.788019, -0.483276,
		0.282042, -0.953394, 0.107205,
		0.530774, 0.847413, 0.0130696,
		0.0515397, 0.922524, 0.382484,
		-0.631467, -0.709046, 0.313852,
		0.688248, 0.517273, 0.508668,
		0.646689, -0.333782, -0.685845,
		-0.932528, -0.247532, -0.262906,
		0.630609, 0.68757, -0.359973,
		0.577805, -0.394189, 0.714673,
		-0.887833, -0.437301, -0.14325,
		0.690982, 0.174003, 0.701617,
		-0.866701, 0.0118182, 0.498689,
		-0.482876, 0.727143, 0.487949,
		-0.577567, 0.682593, -0.447752,
		0.373768, 0.0982991, 0.922299,
		0.170744, 0.964243, -0.202687,
		0.993654, -0.035791, -0.106632,
		0.587065, 0.4143, -0.695493,
		-0.396509, 0.26509, -0.878924,
		-0.0866853, 0.83553, -0.542563,
		0.923193, 0.133398, -0.360443,
		0.00379108, -0.258618, 0.965972,
		0.239144, 0.245154, -0.939526,
		0.758731, -0.555871, 0.33961,
		0.295355, 0.309513, 0.903862,
		0.0531222, -0.91003, -0.411124,
		0.270452, 0.0229439, -0.96246,
		0.563634, 0.0324352, 0.825387,
		0.156326, 0.147392, 0.976646,
		-0.0410141, 0.981824, 0.185309,
		-0.385562, -0.576343, -0.720535,
		0.388281, 0.904441, 0.176702,
		0.945561, -0.192859, -0.262146,
		0.844504, 0.520193, 0.127325,
		0.0330893, 0.999121, -0.0257505,
		-0.592616, -0.482475, -0.644999,
		0.539471, 0.631024, -0.557476,
		0.655851, -0.027319, -0.754396,
		0.274465, 0.887659, 0.369772,
		-0.123419, 0.975177, -0.183842,
		-0.223429, 0.708045, 0.66989,
		-0.908654, 0.196302, 0.368528,
		-0.95759, -0.00863708, 0.288005,
		0.960535, 0.030592, 0.276472,
		-0.413146, 0.907537, 0.0754161,
		-0.847992, 0.350849, -0.397259,
		0.614736, 0.395841, 0.68221,
		-0.503504, -0.666128, -0.550234,
		-0.268833, -0.738524, -0.618314,
		0.792737, -0.60001, -0.107502,
		-0.637582, 0.508144, -0.579032,
		0.750105, 0.282165, -0.598101,
		-0.351199, -0.392294, -0.850155,
		0.250126, -0.960993, -0.118025,
		-0.732341, 0.680909, -0.0063274,
		-0.760674, -0.141009, 0.633634,
		0.222823, -0.304012, 0.926243,
		0.209178, 0.505671, 0.836984,
		0.757914, -0.56629, -0.323857,
		-0.782926, -0.339196, 0.52151,
		-0.462952, 0.585565, 0.665424,
		0.61879, 0.194119, -0.761194,
		0.741388, -0.276743, 0.611357,
		0.707571, 0.702621, 0.0752872,
		0.156562, 0.819977, 0.550569,
		-0.793606, 0.440216, 0.42,
		0.234547, 0.885309, -0.401517,
		0.132598, 0.80115, -0.58359,
		-0.377899, -0.639179, 0.669808,
		-0.865993, -0.396465, 0.304748,
		-0.624815, -0.44283, 0.643046,
		-0.485705, 0.825614, -0.287146,
		-0.971788, 0.175535, 0.157529,
		-0.456027, 0.392629, 0.798675,
		-0.0104443, 0.521623, -0.853112,
		-0.660575, -0.74519, 0.091282,
		-0.0157698, -0.307475, -0.951425,
		-0.603467, -0.250192, 0.757121,
		0.506876, 0.25006, 0.824952,
		0.255404, 0.966794, 0.00884498,
		0.466764, -0.874228, -0.133625,
		0.475077, -0.0682351, -0.877295,
		-0.224967, -0.938972, -0.260233,
		-0.377929, -0.814757, -0.439705,
		-0.305847, 0.542333, -0.782517,
		0.26658, -0.902905, -0.337191,
		0.0275773, 0.322158, -0.946284,
		0.0185422, 0.716349, 0.697496,
		-0.20483, 0.978416, 0.0273371,
		-0.898276, 0.373969, 0.230752,
		-0.00909378, 0.546594, 0.837349,
		0.6602, -0.751089, 0.000959236,
		0.855301, -0.303056, 0.420259,
		0.797138, 0.0623013, -0.600574,
		0.48947, -0.866813, 0.0951509,
		0.251142, 0.674531, 0.694216,
		-0.578422, -0.737373, -0.348867,
		-0.254689, -0.514807, 0.818601,
		0.374972, 0.761612, 0.528529,
		0.640303, -0.734271, -0.225517,
		-0.638076, 0.285527, 0.715075,
		0.772956, -0.15984, -0.613995,
		0.798217, -0.590628, 0.118356,
		-0.986276, -0.0578337, -0.154644,
		-0.312988, -0.94549, 0.0899272,
		-0.497338, 0.178325, 0.849032,
		-0.101136, -0.981014, 0.165477,
		-0.521688, 0.0553434, -0.851339,
		-0.786182, -0.583814, 0.202678,
		-0.565191, 0.821858, -0.0714658,
		0.437895, 0.152598, -0.885981,
		-0.92394, 0.353436, -0.14635,
		0.212189, -0.815162, -0.538969,
		-0.859262, 0.143405, -0.491024,
		0.991353, 0.112814, 0.0670273,
		0.0337884, -0.979891, -0.196654,
	];

}