shader_type canvas_item;

// --- 输入 ---
// 1. 屏幕背景 (读取 ColorRect 下方的岩石、泥土等)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// 2. 矿脉纹理 (通用的一张噪点图/裂纹图，不需要和地形形状匹配)
// 在 GDScript 里通过 set_shader_parameter("overlay_texture", ...) 传入
uniform sampler2D overlay_texture : filter_nearest, repeat_enable;

// --- 设置 ---
// 矿物颜色 (金/银/铜)
uniform vec4 overlay_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
// 混合强度
uniform float blend_intensity : hint_range(0.0, 1.0) = 1.0;

// --- 【核心】智能抠图设置 ---
// 目标岩石颜色 (请用取色器吸取你岩石图片中间最稳的那个灰色)
uniform vec4 target_color : source_color = vec4(0.35, 0.35, 0.40, 1.0); 

// 容差 (容许颜色有多少偏差)
// 调小：只匹配精准的灰色，边缘更锐利，可能漏掉阴影
// 调大：匹配范围广，但可能把泥土也算进去
uniform float color_threshold : hint_range(0.0, 1.0) = 0.16;

// 叠加混合算法 (Overlay)
float overlay(float base, float blend) {
	if (base < 0.5) {
		return 2.0 * base * blend;
	} else {
		return 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
	}
}

vec3 overlay_vec3(vec3 base, vec3 blend) {
	return vec3(overlay(base.r, blend.r), overlay(base.g, blend.g), overlay(base.b, blend.b));
}

void fragment() {
	// 1. 读取背景颜色 (ColorRect 盖住的内容)
	vec4 bg_color = texture(screen_texture, SCREEN_UV);

	// 2. 【核心逻辑】色值检测
	// 计算当前像素的背景色，和我们设定的"岩石色"相差多少
	float diff = distance(bg_color.rgb, target_color.rgb);

	// 3. 【绝对排除】
	// 如果色差超过容差（说明这个像素下面是泥土、草地、或者是半透明的边缘），
	// 直接丢弃该像素！ColorRect 在这里变透明。
	if (diff > color_threshold) {
		discard;
	}

	// --- 只有通过了上面检查的像素(确认为岩石)，才会执行下面的绘制 ---

	// 4. 读取矿脉纹理 (使用 ColorRect 自身的 UV，平铺一张通用的矿图)
	vec4 noise_tex = texture(overlay_texture, UV);
	
	// 矿脉本身的透明剔除 (只画纹理部分)
	if (noise_tex.a < 0.01) {
		discard;
	}

	// 5. 执行混合 (Overlay)
	vec3 blend_src = noise_tex.rgb * overlay_color.rgb;
	vec3 final_rgb = overlay_vec3(bg_color.rgb, blend_src);
	
	// 6. 计算最终 Alpha
	float final_alpha = noise_tex.a * overlay_color.a * blend_intensity * COLOR.a;

	// 7. 输出混合结果
	vec3 result = mix(bg_color.rgb, final_rgb, final_alpha);
	
	// 输出不透明颜色 (因为我们已经排除了非岩石区域，且混合了背景)
	COLOR = vec4(result, 1.0);
}