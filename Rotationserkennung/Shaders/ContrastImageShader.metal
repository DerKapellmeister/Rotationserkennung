//
//  ContrastImageShader.metal
//  smartCam
//
//  Created by Jonas on 04.01.20.
//  Copyright © 2020 Jonas. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void contrast_shader(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
){
    
    int wEnd = 1;
    int wStart = -1 * wEnd;
    
    float maxVal = 0;
    float minVal = 1;
    
    for (int x = wStart; x <= wEnd; x++)
    {
        for (int y = wStart; y <= wEnd; y++)
        {
            if(x == 0 && y == 0) { continue; }
            uint2 textureIndex(gid.x + x, gid.y + y);
            float4 color = input.read(textureIndex);
            
            float grayVal = (0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b);
            
            if(grayVal > maxVal){
                maxVal = grayVal;
            }
            if(grayVal < minVal){
                minVal = grayVal;
            }
        }
    }
    
    float c = ( (maxVal - minVal) / (maxVal + minVal + 0.00001) );

    float4 color(c, c, c, 1);
    output.write(color, gid);

}
