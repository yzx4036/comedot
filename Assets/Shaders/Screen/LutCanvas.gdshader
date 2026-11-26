// LutCanvas —— 调色板感知的明暗调整（LutLight2D 思路的 Godot 4 实现）
//
// 不用 multiply / lerp 压暗：那会把画面拉灰、把饱和色洗淡。
// 而是给调色板的每个颜色预定义一条「同色族明度阶梯」，压暗时换成同族里更暗的
// 真实调色板色——色相与饱和度天然保持，输出永远落在调色板内。
//
// ramp 图约定（由 _ToolScript/gen_palette_ramp.py 生成）：
//   X 轴 = 调色板第 i 色；Y 轴 = 明度档（上暗下亮）；中间行 = 原色
//   因此调色板本身也能从中间行读出来，shader 不需要额外传色板数组
//
// 用法：全屏 ColorRect + 本 ShaderMaterial，ramp_texture 指到 north_ramp_7.png
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// source_color 让 ramp 采样值进线性空间；比较距离时 src 也要转线性，两边才同空间
uniform sampler2D ramp_texture : filter_nearest, repeat_disable;

// 暗部要压几档、亮部要提几档（P1 默认各 1 档 = 「两档」）
uniform float dark_steps : hint_range(0.0, 3.0) = 1.0;
uniform float bright_steps : hint_range(0.0, 3.0) = 1.0;

// 明暗分界（CIE L*，0..100）。区间内线性过渡到 0 档，区间外渐强
uniform float dark_lstar : hint_range(0.0, 100.0) = 38.0;
uniform float bright_lstar : hint_range(0.0, 100.0) = 62.0;

// 与原始画面的混合量。1 = 全用 ramp 色，0 = 原样输出
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;

// 越界放过阈值（RGB 归一化欧氏距离）。0 = 不限制，总是吸附到最近色。
//
// 为什么要这个：调色板内部的最近邻距离中位约 0.088，而 pixelfx 特效像素到最近
// north 色的距离中位是 0.10~0.12、P90 到 0.45——它们落在色板网格的空隙里。
// 无条件吸附会把特效的青/蓝/紫光晕揉成土色，画面直接变脏。
// 设成 0.06：精确的调色板色（距离 0）照常处理，越界的内容原样放过。
uniform float max_match_distance : hint_range(0.0, 0.5) = 0.06;

// 调试：0 正常；1 输出调色板索引灰度；2 输出档位灰度
uniform int debug_mode : hint_range(0, 2) = 0;


float srgb_to_linear(float c) {
	return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

// CIE L*（0..100）。ramp 的色族就是按 L* 排序的，用同一度量才不会错档
float lstar(vec3 c) {
	float y = dot(vec3(srgb_to_linear(c.r), srgb_to_linear(c.g), srgb_to_linear(c.b)),
			vec3(0.2126729, 0.7151522, 0.0721750));
	return y > 0.008856 ? 116.0 * pow(y, 1.0 / 3.0) - 16.0 : 903.3 * y;
}


void fragment() {
	vec3 src = texture(screen_texture, SCREEN_UV).rgb;

	// ramp 图自描述尺寸：宽 = 调色板色数，高 = 明度档数
	ivec2 sz = textureSize(ramp_texture, 0);
	int n = max(sz.x, 1);
	int bands = max(sz.y, 1);
	int center = bands / 2;
	float inv_n = 1.0 / float(n);
	float inv_b = 1.0 / float(bands);

	// 在调色板里找最近色。采样点用像素中心，配合 filter_nearest 拿到精确值。
	// ramp 不加 source_color，读到的就是 PNG 里的 sRGB 原值，与屏幕采样同空间。
	float best = 1e20;
	int idx = 0;
	for (int i = 0; i < 64; i++) {
		if (i >= n) {
			break;
		}
		vec3 pal = texture(ramp_texture, vec2((float(i) + 0.5) * inv_n,
				(float(center) + 0.5) * inv_b)).rgb;
		vec3 d = src - pal;
		// 加权：色相/饱和度差异比明度差异更该被避免，否则暗色会跳到别的色族
		float dist = dot(d * d, vec3(1.0, 1.0, 1.0));
		if (dist < best) {
			best = dist;
			idx = i;
		}
	}

	// 越界判定：非调色板内容（特效、任意 RGB、UI 残留）应原样输出，不揉进色板
	bool isOutOfRange = max_match_distance > 0.0 && sqrt(best) > max_match_distance;

	// L* 归一化到 0..1，再转成档位偏移
	float L = lstar(src);
	float t = clamp((L - dark_lstar) / max(bright_lstar - dark_lstar, 0.001), 0.0, 1.0);
	float offset;
	if (t < 0.5) {
		offset = mix(-dark_steps, 0.0, t * 2.0);
	} else {
		offset = mix(0.0, bright_steps, (t - 0.5) * 2.0);
	}
	int band = clamp(center + int(floor(offset + 0.5)), 0, bands - 1);

	vec3 shaded = texture(ramp_texture, vec2((float(idx) + 0.5) * inv_n,
			(float(band) + 0.5) * inv_b)).rgb;

	// 注意：Godot 的 fragment() 里不能用 return 提前退出（会 SHADER ERROR），
	// 所以所有分支统一落到一个 result 再一次性写 COLOR。
	vec3 result;
	if (debug_mode == 1) {
		// 索引视图：越界像素标成品红，方便一眼看出哪些内容没被调色板覆盖
		result = isOutOfRange ? vec3(1.0, 0.0, 1.0) : vec3(float(idx) / max(float(n - 1), 1.0));
	} else if (debug_mode == 2) {
		result = isOutOfRange ? vec3(0.5, 0.0, 0.5) : vec3(float(band) / max(float(bands - 1), 1.0));
	} else if (isOutOfRange) {
		result = src;
	} else {
		result = mix(src, shaded, mix_amount);
	}
	COLOR = vec4(result, 1.0);
}
