#include "ReShadeUI.fxh"

// How many pixels should the "radius" of a single hexagon be? The true number of pixels will be
// approximately 1/3rd of this
// eg if you set it to 6 at 1080p you get an image resolution of 1080/6 = 180p
// but since only 1/3 of the pixels are filled. this becomes 180 * sqrt(1/3) = 103p.
// Large moths and dragonflies are about 130p
// while smaller ones may be only around 40-90p so take that into account when choosing your value.
//
//
// note that the larger/more predatory the insect, the larger the eyes,
// if humans were insects at our eye size we would be approximately 360p or so I think
// but if you set it that way the effect becomes very hard to see so I would not recommend :(
#define HEXAGON_RADIUS 8

// Insects have fixed focus distances so 
// Distance at which everything is in focus
uniform float FOCUSED_DISTANCE <
    ui_category = "Insect vision";
    ui_label = "Focused Distance";
    ui_max = 1000;
    ui_min = -1000;
    ui_step = 0.001;
    ui_tooltip = "Distance at which stuff is in focus. Since every game and its mother uses its own distance system you will need to play with this for each game.";
    ui_type = "slider";
> = 0.3;
// Minimum distance for stuff to be fully out of focus
uniform float UNFOCUSED_CLOSE <
    ui_category = "Insect vision";
    ui_label = "Insect Unfocused Close";
    ui_max = 1000;
    ui_min = -1000;
    ui_step = 0.001;
    ui_tooltip = "Distance at which stuff is completely out of focus because it is too close. Since every game and its mother uses its own distance system you will need to play with this for each game. Please set to less than FOCUSED_DISTANCE";
    ui_type = "slider";
> = 0.1;
// Maximum distance for stuff to be fully out of focus
uniform float UNFOCUSED_FAR <
    ui_category = "Insect vision";
    ui_label = "Insect Unfocused Far";
    ui_max = 1000;
    ui_min = -1000;
    ui_step = 0.001;
    ui_tooltip = "Distance at which stuff is completely out of focus because it is too far away. Since every game and its mother uses its own distance system you will need to play with this for each game.";
    ui_type = "slider";
> = 1.8;

uniform float DEPTH_MULTIPLIER <
    ui_category = "Depth Adjusting";
    ui_label = "Depth Multiply";
    ui_max = 1000;
    ui_min = 0.001;
    ui_step = 0.001;
    ui_tooltip = "Value to multiply depth by, in case the engine you are using made everything super close together or super far apart.";
    ui_type = "slider";
> = 1.0;

uniform float DEPTH_ADD <
    ui_category = "Depth Adjusting";
    ui_label = "Depth Add";
    ui_max = 100;
    ui_min = -100;
    ui_step = 0.1;
    ui_tooltip = "Value to add to depth before doing any calculations, in case the engine has some weird offset. Adding happens AFTER multiplication";
    ui_type = "slider";
> = 0.0;

uniform float UI_DEPTH_MIN <
    ui_category = "Depth Adjusting";
    ui_label = "UI Depth Minimum";
    ui_max = 1;
    ui_min = -1;
    ui_step = 0.001;
    ui_tooltip = "Minimum depth of UI elements. UI elements are always in focus. To disable this feature set above UI_DEPTH_MAX";
    ui_type = "slider";
> = -0.005;

uniform float UI_DEPTH_MAX <
    ui_category = "Depth Adjusting";
    ui_label = "UI Depth Maximum";
    ui_max = 1;
    ui_min = -1;
    ui_step = 0.001;
    ui_tooltip = "Maximum depth of UI elements";
    ui_type = "slider";
> = 0.005;

#include "ReShade.fxh"
texture LowResTex  { Width = BUFFER_WIDTH / HEXAGON_RADIUS; Height = 2 * BUFFER_HEIGHT / HEXAGON_RADIUS / 3; Format = RGBA8; };
sampler LowResColor { Texture = LowResTex; };

float Get_Weighting(float2 texcoord) {
    float c = ReShade::GetLinearizedDepth(texcoord);
    c *= DEPTH_MULTIPLIER;
    c += DEPTH_ADD;
    
    float lerpAmt = 0.0;
    if (c <= FOCUSED_DISTANCE) {
        lerpAmt = (FOCUSED_DISTANCE - c) / (FOCUSED_DISTANCE - UNFOCUSED_CLOSE);
    } else {
        lerpAmt = (FOCUSED_DISTANCE - c) / (FOCUSED_DISTANCE - UNFOCUSED_FAR);
    }

    if (lerpAmt > 1.0) {
        lerpAmt = 1.0;
    }
    // For UI elements
    
    if (c <= UI_DEPTH_MAX && c >= UI_DEPTH_MIN) {
        lerpAmt = 0;
    }
    return lerpAmt;
}

float3 Insect_DT(float4 vpos:SV_Position, float2 texcoord:TexCoord) : SV_Target {
    float3 lowRes = float3(0, 0, 0);
    // Only sample every 8x8 pixels.
    float xPos = texcoord.x * BUFFER_WIDTH / HEXAGON_RADIUS;
    float yPos = texcoord.y * BUFFER_HEIGHT / HEXAGON_RADIUS * 2.0 / 3.0;
    // Hexagon only covers even values
    if ( (floor(xPos) + floor(yPos)) % 2 != 0) {
        //return lowRes;
        // we should write all values because rounding is duuuumb
    }
    float totalWeighting = 0.0;

    for (float i = (-HEXAGON_RADIUS - 1); i <= HEXAGON_RADIUS; i += 1)
    {
        for (float j = (-HEXAGON_RADIUS - 1); j <= HEXAGON_RADIUS; j += 1)
        {
            // Value is outside the top left
            if ((i / BUFFER_WIDTH) + texcoord.x < 0 || (j/BUFFER_HEIGHT) + texcoord.y < 0) {
                continue;
            }
            // Value is outside hexagon in those triangle regions
            if ( abs(i) > HEXAGON_RADIUS - (0.5 * abs(j))) {
                continue;
            }
            
            
            float weight = Get_Weighting(float2(
            (i / BUFFER_WIDTH) + texcoord.x, (j/BUFFER_HEIGHT) + texcoord.y));
            if (weight < 0.25) {
                weight = 0.000001;
            }
            totalWeighting += weight;
            lowRes.xyz += (weight * (tex2D(ReShade::BackBuffer,float2(
            (i / BUFFER_WIDTH) + texcoord.x, (j/BUFFER_HEIGHT) + texcoord.y)).xyz));
        }
    }
    lowRes.xyz /= totalWeighting;
    return lowRes;
}

float2 GetTruePos(float2 texcoord) {
    float xPos = texcoord.x * BUFFER_WIDTH / HEXAGON_RADIUS;
    // yPos in number of grid spaces. every 3 grid spaces is a triangle space. if u are in
    // the triangle zone. you need to do special math
    float yPosHex = texcoord.y * BUFFER_HEIGHT / HEXAGON_RADIUS * 2.0 / 3.0;
    float yPos = yPosHex * 3.0 + 1;
    // If we are between hexagons
    if ( (yPos % 3.0) >= 2.0) {
        float height = (yPos % 3.0) - 2.0;
        float l = xPos % 1.0;
        float sum = (floor(xPos) + floor(yPosHex)) % 2.0;
        // get triangle type. if xPos + yPosHex is even then l = 1 - l
        if (sum < 0.5) {
            l = 1 - l;
        }
        if ( (height - l) > 0) {
            yPosHex = yPosHex + 1;
        }
    } else if ((yPos % 3.0) < 1.0) {
        // we're in the rectangle "normal" region, but in the top half of it. Add 1 to yPosHex and check
        // that our hex plus our x value is even. if not move x to closer value
        yPosHex = yPosHex + 1;
    }
    float simplePos = floor(yPosHex) + floor(xPos);
    if (simplePos % 2 > 0.5) {
        xPos = xPos + 1;
    }
    // if xPos is even yPosHex will be even and vice versa.
    
    float trueXPos = (floor(xPos) + 0.5) * HEXAGON_RADIUS / BUFFER_WIDTH;
    float trueYPos = (floor(yPosHex) + 0.5) / 2.0 * HEXAGON_RADIUS / BUFFER_HEIGHT * 3.0;
    return float2(trueXPos, trueYPos);
}


float3 Insect_PS(float4 vpos:SV_Position, float2 texcoord:TexCoord): SV_Target {
    float lerpAmt = Get_Weighting(texcoord);
    return lerp(tex2D(ReShade::BackBuffer, texcoord).xyz, tex2D(LowResColor, GetTruePos(texcoord)).xyz, lerpAmt);
}


technique DayInsect {
    pass insect_Detect {
        VertexShader = PostProcessVS;
        PixelShader = Insect_DT;
        RenderTarget = LowResTex;
    }
    
    pass insect_Generate {
        VertexShader = PostProcessVS; 
        PixelShader = Insect_PS; 
    }
}
