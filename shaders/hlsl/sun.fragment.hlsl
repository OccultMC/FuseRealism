#include "ShaderConstants.fxh"
#include "Util.fxh"

struct PS_Input
{
    float4 position : SV_Position;
	float3 xyz : XYZ_POS;
    float2 uv : TEXCOORD_0_FB_MSAA;
};

struct PS_Output
{
    float4 color : SV_Target;
};

void main( in PS_Input PSInput, out PS_Output PSOutput )
{
#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE) || (VERSION < 0xa000 /*D3D_FEATURE_LEVEL_10_0*/) 
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv);
#else
	float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv);
#endif
   float r = pow(FOG_CONTROL.y,11.0);
   float sun = length(PSInput.xyz*2.0);
	PSOutput.color = ((CURRENT_COLOR-(length(PSInput.xyz*2.2)*CURRENT_COLOR)))*r;
	PSOutput.color += lerp(CURRENT_COLOR*0.5,PSOutput.color, min(max(smoothstep(0.5, 1.0, sun),0.0),1.0))*r;
}