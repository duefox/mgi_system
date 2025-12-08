shader_type canvas_item;

uniform vec4 inactive_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cooldown_bg: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 active_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float overlay_strength : hint_range(0.0, 1.0) = 0.0;
uniform float bg_overlay_strength : hint_range(0.0, 1.0) = 0.0;
uniform float active_overlay_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool is_active = false;
uniform bool cooldown_bg_switch = true;

void fragment() {
    vec4 custom_color = texture(TEXTURE, UV);
	vec4 cooldown_bg_color = vec4(0,0,0,0);
	if ((1.0 - UV.y >= progress && custom_color.a != 0.0 && cooldown_bg_switch==true) || (is_active==false && cooldown_bg_switch==true)){
		cooldown_bg_color.rgb = mix(custom_color.rgb, cooldown_bg.rgb, bg_overlay_strength);
		cooldown_bg_color.a = COLOR.a;
		COLOR = cooldown_bg_color;
	}
    if (1.0 - UV.y <= progress && custom_color.a != 0.0 && is_active==false) {
        // Mix the overlay color with the original color using overlay_strength
        custom_color.rgb = mix(custom_color.rgb, inactive_color.rgb, overlay_strength);
        custom_color.a = COLOR.a;
        COLOR = custom_color;
    }
	if (custom_color.a != 0.0 && is_active==true)
	{
		custom_color.rgb = mix(custom_color.rgb, active_color.rgb, active_overlay_strength);
		custom_color.a = COLOR.a;
		custom_color.a = COLOR.a;
		COLOR = custom_color;
	}
}
