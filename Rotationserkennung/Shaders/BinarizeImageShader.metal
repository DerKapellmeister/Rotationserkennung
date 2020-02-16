//
//  ContrastImageShader.metal
//  smartCam
//
//  Created by Jonas on 05.01.20.
//  Copyright © 2020 Jonas. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void binarize_shader(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::read> contrastImage [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
){
    
    int wEnd = 1;
    int wStart = -1 * wEnd;
    
    float4 white(1, 1, 1, 1);
    float4 black(0, 0, 0, 1);

    
    float e_mean = 0;
    float e_std = 1;
    float n_e = 0;
    float n_min = 5;
    
    float mean_sum = 0;
    
    for (int x = wStart; x <= wEnd; x++)
    {
        for (int y = wStart; y <= wEnd; y++)
        {
            if(x == 0 && y == 0) { continue; }

            uint2 textureIndex(gid.x + x, gid.y + y);
            float4 color = contrastImage.read(textureIndex);
            float4 colori = input.read(textureIndex);
            float grayVal = (0.2125 * colori.r) + (0.7154 * colori.g) + (0.0721 * colori.b);
            mean_sum += grayVal * color.r;

            if(color.r > 0.2) {
                n_e++;
            }
        }
    }

    if(n_e >= n_min) {
        
        float std_sum = 0;
                
        e_mean = mean_sum / n_e;
        
        for (int x = wStart; x <= wEnd; x++)
        {
            for (int y = wStart; y <= wEnd; y++)
            {
                if(x == 0 && y == 0) { continue; }

                uint2 textureIndex(gid.x + x, gid.y + y);
                float4 colori = input.read(textureIndex);
                
                float colorc = contrastImage.read(textureIndex).r;
                float grayVal = (0.2125 * colori.r) + (0.7154 * colori.g) + (0.0721 * colori.b);
                
                std_sum += ((grayVal - e_mean) * colorc) * ((grayVal - e_mean) * colorc);
            }
        }

        e_std = sqrt((std_sum / 2));
        
        float4 colori = input.read(gid);
        float grayVal = (0.2125 * colori.r) + (0.7154 * colori.g) + (0.0721 * colori.b);
        
        float checkVal = (e_mean + (e_std / 2));
        if(grayVal <= checkVal) {

            output.write(black, gid);

        }else {
            output.write(white, gid);

        }

    }else {
        output.write(white, gid);
    }

}
