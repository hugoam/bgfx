$input a_position, a_indices

/*
 * Copyright 2011-2020 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#define BGFX_CONFIG_MAX_BONES 32
#include <bgfx_shader.sh>

void main()
{
	vec4 model = mul(u_model[int(a_indices.x)], vec4(a_position, 1.0) );
	gl_Position = mul(u_viewProj, model);
}
