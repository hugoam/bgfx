$input v_color0

/*
 * Copyright 2011-2019 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "../common/common.sh"

uniform vec4 u_color;

void main()
{
	gl_FragColor = vec4(u_color.rgb, 1.0);
}
