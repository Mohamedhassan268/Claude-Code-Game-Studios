// Ground colours, with ash and flows drawn from the replay's hazard frames.
shader_type spatial;

uniform sampler2D ash_map : filter_linear, repeat_disable;
uniform sampler2D flow_map : filter_linear, repeat_disable;

const vec3 ASH_COLOUR = vec3(0.56, 0.54, 0.51);
const vec3 FLOW_COLOUR = vec3(0.95, 0.30, 0.06);

void fragment() {
	float ash = texture(ash_map, UV).r;
	float flow = texture(flow_map, UV).r;
	vec3 ground = mix(COLOR.rgb, ASH_COLOUR, smoothstep(0.0, 1.0, ash));
	ALBEDO = mix(ground, FLOW_COLOUR, flow);
	EMISSION = FLOW_COLOUR * flow * 1.5;
	ROUGHNESS = 0.95;
}
