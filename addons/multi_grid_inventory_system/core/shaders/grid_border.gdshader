shader_type canvas_item;

// 接收 GDScript 传来的边框颜色
uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
// 边框宽度（物理像素），设为 1.0 即可保证永远是 1 像素
uniform float border_width_px = 1.0; 

void fragment() {
	// fwidth 获取屏幕像素对应的 UV 宽度
	vec2 fw = fwidth(UV);
	vec2 border_uv = fw * border_width_px;
	
	// 检测是否处于边缘
	if (UV.x < border_uv.x || UV.x > 1.0 - border_uv.x || 
		UV.y < border_uv.y || UV.y > 1.0 - border_uv.y) {
		COLOR = border_color;
	} else {
		// 核心修改：中间部分直接丢弃（透明），露出底下的 BaseGridView 内容
		COLOR = vec4(0.0); 
	}
}