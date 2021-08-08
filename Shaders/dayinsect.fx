#include "ReShadeUI.fxh"

// Minimum resolution reduction factor. Maximum for some large moths and dragonflies is ~130p or 8 for 1080p (1080/8 = 130p)
#define MACROBLOCK_SIZE 8

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
> = 0.7;
// Minimum distance for stuff to be fully out of focus
uniform float UNFOCUSED_CLOSE <
    ui_category = "Insect vision";
    ui_label = "Insect Unfocused Close";
    ui_max = 1000;
    ui_min = -1000;
    ui_step = 0.001;
    ui_tooltip = "Distance at which stuff is completely out of focus because it is too close. Since every game and its mother uses its own distance system you will need to play with this for each game. Please set to less than FOCUSED_DISTANCE";
    ui_type = "slider";
> = -0.5;
// Maximum distance for stuff to be fully out of focus
uniform float UNFOCUSED_FAR <
    ui_category = "Insect vision";
    ui_label = "Insect Unfocused Far";
    ui_max = 1000;
    ui_min = -1000;
    ui_step = 0.001;
    ui_tooltip = "Distance at which stuff is completely out of focus because it is too far away. Since every game and its mother uses its own distance system you will need to play with this for each game.";
    ui_type = "slider";
> = 2.5;

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
texture LowResTex  { Width = BUFFER_WIDTH / MACROBLOCK_SIZE; Height = BUFFER_HEIGHT / MACROBLOCK_SIZE; Format = RGBA8; };
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
    float xPos = texcoord.x * BUFFER_WIDTH / MACROBLOCK_SIZE;
    float yPos = texcoord.y * BUFFER_HEIGHT / MACROBLOCK_SIZE;
    float totalWeighting = 0.0;

    for (float i = 0.0; i < MACROBLOCK_SIZE; i += 1)
    {
        for (float j = 0.0; j < MACROBLOCK_SIZE; j += 1)
        {
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
    float xPos = texcoord.x * BUFFER_WIDTH / MACROBLOCK_SIZE;
    float yPos = texcoord.y * BUFFER_HEIGHT / MACROBLOCK_SIZE;
    float trueXPos = (floor(xPos) + 0.5) * MACROBLOCK_SIZE / BUFFER_WIDTH;
    float trueYPos = (floor(yPos) + 0.5) * MACROBLOCK_SIZE / BUFFER_HEIGHT;
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
