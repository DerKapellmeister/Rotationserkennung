//
//  FillCharShader.metal
//  smartCam
//
//  Created by Jonas on 01.02.20.
//  Copyright © 2020 Jonas. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void fill_char_shader(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
){
    
    float4 black(0, 0, 0, 1);
    float4 white(1, 1, 1, 1);
    
    float4 curColor = input.read(gid);
    float curColorGray = (0.2125 * curColor.r) + (0.7154 * curColor.g) + (0.0721 * curColor.b);
    
    if(curColorGray >= 0.8){
        output.write(white, gid);
    }

    int countBlackPixel = 0;
    
    int wEnd = 2;
    int wStart = -1 * wEnd;
    
    for (int x = wStart; x <= wEnd; x++)
    {
        for (int y = wStart; y <= wEnd; y++)
        {
            if(x == 0 && y == 0) { continue; }
            uint2 textureIndex(gid.x + x, gid.y + y);
            float4 color = input.read(textureIndex);

            float grayVal = (0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b);

            if(grayVal >= 0.8){
                countBlackPixel++;
            }
        }
    }
    
//    int limit_x = 15;
//    int limit_y = limit_x;
//
//    for (int x = 1; x <= limit_x; x++){
//        uint2 idx(gid.x + x, gid.y);
//        float4 color = input.read(idx);
//        float grayVal = (0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b);
//        if(grayVal >= 0.8){
//            countBlackPixel++;
//            break;
//        }
//    }
//
//    for (int x = 1; x <= limit_x; x++){
//        uint2 idx(gid.x + (-1 * x), gid.y);
//        float4 color = input.read(idx);
//        float grayVal = (0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b);
//        if(grayVal >= 0.8){
//            countBlackPixel++;
//            break;
//        }
//    }
//
//
//    for (int y = 1; y <= limit_y; y++){
//        uint2 idx(gid.x, gid.y + y);
//        float4 color = input.read(idx);
//        float grayVal = (0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b);
//        if(grayVal >= 0.8){
//            countBlackPixel++;
//            break;
//        }
//    }
//
//
//    for (int y = 1; y <= limit_y; y++){
//        uint2 idx(gid.x, gid.y + (-1 * y));
//        float4 color = input.read(idx);
//        float grayVal = (0.2125 * color.r) + (0.7154 * color.g) + (0.0721 * color.b);
//        if(grayVal >= 0.8){
//            countBlackPixel++;
//            break;
//        }
//    }

    
    if(countBlackPixel >= 13){
        output.write(white, gid);
    }else{
        output.write(curColor, gid);
    }

}

