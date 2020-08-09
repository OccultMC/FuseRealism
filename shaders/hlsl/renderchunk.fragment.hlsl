#include "ShaderConstants.fxh"
#include "util.fxh"

struct PS_Input
{
	float4 position : SV_Position;
    float3 pos : POS;
	float3 p : P;
	float3 look : LOOK;
	float fp : FP;
	float3 s : S;
#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 color : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif

#ifdef NEAR_WATER
	float cameraDist : TEXCOORD_2;
#endif

#ifdef FOG
	float4 fogColor : FOG_COLOR;
#endif
};

struct PS_Output
{
	float4 color : SV_Target;
};

#ifndef BYPASS_PIXEL_SHADER
  float random(  float x){
	return frac(sin(x) * 428.123);
}

  float srandom(  float x){
	  float r1 = random(floor(x));
	  float r2 = random(floor(x) + 1.0);
	return lerp(r1, r2, smoothstep(0.0, 1.0, frac(x)));
}

  float srandom2d(  float x,   float y){
	  float r1 = srandom(x + floor(y) * 100.0);
	  float r2 = srandom(x + floor(y) * 100.0 + 100.0);
	return lerp(r1, r2, smoothstep(0.0, 1.0, frac(y)));
}

  float angle_between_vecs(  float3 v1,   float3 v2){
 return acos((v1.x * v2.x + v1.y * v2.y + v1.z * v2.z) / length(v1) / length(v2));
}

  float2 normalmapuv(  float3 coords,float2 uv0,float3 position){
	  float2 uv = uv0;
	  float2 pos = frac(position.xz); 
	return uv - pos / 8.0 + frac(coords.xz / 10.0) / 8.0;
}

  float3 normalfromcolor(  float4 color){
	return float3(color.r - .5, color.b, color.g - .5);
}

float colormatch(float3 color1, float3 color2, float t){
	if (length(color1 - color2) < t){
		return 1.0;
	}
	return 0.0;
}

float4 skymap(  float3 coords, float4 ambient, float4 light){

coords /= 10.0;
  float cloud_intense = srandom2d(coords.x, coords.z);
  float cloud_modifier = srandom2d(coords.x, coords.z + 1000.0);

float4 clr = float4(0.2, 0.4, 0.6, 0.0);
float CM = 0.2*cloud_modifier;

  float4 skycolor = float4(clr.r, clr.g+CM, clr.b, 0.25) + clamp(cloud_intense * 2.0 - 0.5, 0.0, cloud_modifier) * 0.35 * light * float4(1.0, 1.0, 1.0, 0.8);

return skycolor;
}

float3 water2layermap(  float3 pos,float2 uv0,float3 position){
  float4 normaltex1 = TEXTURE_0.Sample(TextureSampler0, normalmapuv(pos + float3(0.4, 0.0, -.1) * TIME * 0.88,uv0,position));
  float4 normaltex2 = TEXTURE_0.Sample(TextureSampler0, normalmapuv(pos + float3(-.1, 0.0, 0.75) * TIME * 0.88,uv0,position));
  float3 normal = normalize(normalfromcolor(normaltex1) + normalfromcolor(normaltex2) + float3(0.0, 1.0, 0.0));
return normal;
}

float4 watersurface(float4 ambient, float4 light,float2 uv1,float2 uv0,float3 position,float3 look){
  float3 normal;
  float3 pos = position;

normal = water2layermap(pos,uv0,position);

  float3 reflected = reflect(look, normal);

float4 surface = skymap(look + normalize(reflected) * 40.0, ambient, light);

float sunreflect = angle_between_vecs(reflected, float3(0.0, 1.0, -2.5));
float nolight = (1.0 - uv1.x);

if(sunreflect < 0.1){
surface += (float4(10.0,10.0,10.0,10.0)*nolight)*uv1.y;
}

return ambient *= surface;
}
#endif


float filmic_curve(float x) {
float A = 0.22;
float B = 0.3;
float C = 0.15 * 1.0;
float D = 0.4 * 1.77;
float E = 0.01 * 1.0;
float F = 0.1;
return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F; 
} 

float3 toneMap(float3 clr) { 	
float W = 1.3 / 1.0;

float Luma = dot(clr, float3(0.0,0.0,0.0));
float3 Chroma = clr - Luma;
clr = (Chroma * float3(2.2, 2.3, 2.4)) + Luma;
clr = float3(filmic_curve(clr.r), filmic_curve(clr.g), filmic_curve(clr.b)) / filmic_curve(W);

return clr; 
}

float4 moonLight(float4 light, float null , float3 night){

float amount = 1.05;
float colorDesat = dot(light.rgb, float3(0.25,0.25,0.25));

light.rgb = lerp(light.rgb, float3(colorDesat,colorDesat,colorDesat) * night, amount * null);

return light;}

float4 dayLight(float4 light, float null,float3 day){

float4 lum_day = light * float4( day, 0.5);
float4 final_day = lum_day;

return final_day;}

float4 sunLight(float4 light, float null , float3 sun){

float rain = (1.0-pow(FOG_CONTROL.y,5.0));
light.rgb = lerp(light.rgb, light.rgb*max(sun,float3(1.0,1.0,1.0)*rain), null);

return light;}

bool getNetherMask(float4 ambient){
if(ambient.r > ambient.b && ambient.r < 0.5 && ambient.b < 0.05){
return true;
} else {
return false;}
}

bool getTheEndMask(float4 ambient){
if(ambient.r > ambient.g && ambient.b > ambient.g && ambient.r < 0.05 && ambient.b < 0.05 && ambient.g < 0.05){
return true;
} else {
return false;}
}

bool getUnWaterMask(float4 ambient){
if(ambient.b > ambient.r*2.5 &&  ambient.b*3.0 > ambient.g){
return true;
} else {
return false;}
}

#ifndef BYPASS_PIXEL_SHADER
float3 calc_light(float3 color,float2 uv1){
float lum = (color.r + color.g + color.b) - uv1.y*3.0;
float3 light = (color.rgb) * lum;
return light.rgb;}

bool getSandMask(float2 uv){
float2 matID = floor(float2(uv.x * 32.0, uv.y * 32.0));
if((matID.x>=0.0&&matID.y>=12.0&&
     matID.x<=3.0&&matID.y<=12.0)||
    (matID.x>=14.0&&matID.y>=11.0&&
     matID.x<=19.0&&matID.y<=11.0)||
    (matID.x>=28.0&&matID.y>=11.0&&
     matID.x<=30.0&&matID.y<=11.0)){
return true;
} else {
return false;}
}

bool getSnowMask(float2 uv){
float2 matID = floor(float2(uv.x * 32.0, uv.y * 32.0));
if(matID.x==14.0&&matID.y==12.0){
return true;
} else {
return false;}
}

bool getGrassSideSnowedMask(float2 uv){
float2 matID = floor(float2(uv.x * 32.0, uv.y * 32.0));
if(matID.x==26.0&&matID.y==6.0){
return true;
} else {
return false;}
}
#endif
void main( in PS_Input PSInput, out PS_Output PSOutput )
{
#ifdef BYPASS_PIXEL_SHADER
    PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    return;
#else

#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE) || (VERSION < 0xa000 /*D3D_FEATURE_LEVEL_10_0*/) 
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
	float4 uvl = TEXTURE_1.Sample(TextureSampler1, float2(PSInput.uv1.x*0.5,PSInput.uv1.y));
	float4 diffuse2 = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
#else
	float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv0 );
#endif
float4 transf = TEXTURE_1.Sample(TextureSampler1, float2(0.0,1.0));
float setTime = (transf.r - 0.5) / 0.5;
setTime = max(0.0, min(1.0, setTime));


float nolight = (1.0 - PSInput.uv1.x);
float timeNoon = PSInput.uv1.y * setTime;
float timeSunset = (0.5-abs(0.5-setTime))*PSInput.uv1.y;
float timeMidnight = PSInput.uv1.y *(1.0-setTime);
float rain = (1.0-pow(FOG_CONTROL.y,5.0))*PSInput.uv1.y;

float tNoon = timeNoon*timeNoon;
float tSunset = timeSunset*timeSunset;
float tMidnight = timeMidnight*timeMidnight;

float nether = 0.0;

float shadow = 0.0;
float shdX = PSInput.color.w;
float biasY = 0.8810;
float biasX = 0.663;

float3 tl = float3(0.0, 0.0, 0.0);
float3 tlc = float3(0.6, 0.3, 0.0);
float3 AS = float3(0.0, 0.0, 0.0);
float3 ASc = float3(0.0,0.0,1.0)*0.5;

float4 fog = FOG_COLOR;

#ifdef SEASONS_FAR
	diffuse.a = 1.0f;
	PSInput.color.b = 1.0f;
#endif

#ifdef ALPHA_TEST
//If we know that all the verts in a triangle will have the same alpha, we should cull there first.
	#ifdef ALPHA_TO_COVERAGE
		float alphaThreshold = .05f;
	#else
		float alphaThreshold = .5f;
	#endif
	if(diffuse.a < alphaThreshold)
		discard;
#endif

#if !defined(ALWAYS_LIT)
	diffuse = diffuse * TEXTURE_1.Sample(TextureSampler1, float2(PSInput.uv1.x*0.5,PSInput.uv1.y));
#endif

#ifndef SEASONS

#if !defined(ALPHA_TEST) && !defined(BLEND)
	diffuse.a = PSInput.color.a;
#elif defined(BLEND)
#ifdef NEAR_WATER	
	//diffuse.a *= PSInput.color.a;

	//float alphaFadeOut = saturate(PSInput.cameraDist.x);
	//diffuse.a = lerp(diffuse.a, 1.0f, alphaFadeOut);
#endif

#endif	
	diffuse.rgb *= PSInput.color.rgb;
#else
	float2 uv = PSInput.color.xy;
	diffuse.rgb *= lerp(1.0f, TEXTURE_2.Sample(TextureSampler2, uv).rgb*2.0f, PSInput.color.b);
	diffuse.rgb *= PSInput.color.aaa;
	diffuse.a = 1.0f;
#endif
if(getUnWaterMask(fog)){rain = 0.0;}
float noshd = (1.0-PSInput.uv1.x*1.5*tMidnight);
float noshd2 = (1.0-max(0.0,1.0*rain));

float3 day = float3(1.0,1.0,1.0);
float3 night = float3(0.6,0.6,0.6);
float3 sun = float3(1.0,0.44,0.0);

#ifdef NEAR_WATER
diffuse = watersurface(TEXTURE_1.Sample(TextureSampler1, float2(PSInput.uv1.x*1.5,PSInput.uv1.y)), TEXTURE_1.Sample(TextureSampler1, float2(PSInput.uv1.x*1.5,PSInput.uv1.y)),PSInput.uv1,PSInput.uv0,PSInput.p,PSInput.look);
night.rgb *= 1.5;
if(getNetherMask(FOG_COLOR)){
diffuse.rgb = float3(1.0,0.0,0.0);}
#endif

if(PSInput.color.a==0.0){
diffuse.rgb *= 1.15;
shdX = PSInput.color.g*1.4;
biasY = 0.8751;
}

if(getSandMask(PSInput.uv0)){
shdX *= 0.82;
}

if(getSnowMask(PSInput.uv0)){
shdX *= 0.785;
}

if(getGrassSideSnowedMask(PSInput.uv0)){
shdX *= 0.80;
}

if(getTheEndMask(fog)){
tlc.rgb = float3(0.5,0.0,1.5);
ASc.rgb = diffuse.rgb * float3(5.0,0.0,10.0);
diffuse.rgb *= 0.25;
}

tl.rgb = calc_light(tlc.rgb*3.0,PSInput.uv1)*pow(PSInput.uv1.x*0.9,3.0);
diffuse.rgb += (diffuse.rgb * (tlc.rgb*3.0-1.0) * pow(PSInput.uv1.x*0.9, 0.5))*tMidnight;
if((PSInput.uv1.y<biasY-0.0005)||(shdX<biasX-0.0000))
{diffuse.rgb += diffuse.rgb * tl;}

if(getNetherMask(fog)){
nether = 1.0;
diffuse.rgb *= 0.3 + tl * 0.25;
}

if(nether==0.0){
AS.rgb = ASc.rgb;
}

if((PSInput.uv1.y<biasY-0.0005)||(shdX<biasX-0.0000))
{shadow = 0.05;}
if((PSInput.uv1.y<biasY-0.0010)||(shdX<biasX-0.0030))
{shadow = 0.10;}
if((PSInput.uv1.y<biasY-0.0015)||(shdX<biasX-0.0050))
{shadow = 0.15;}
if((PSInput.uv1.y<biasY-0.0020)||(shdX<biasX-0.0080))
{shadow = 0.20;}
if((PSInput.uv1.y<biasY-0.0025)||(shdX<biasX-0.0100))
{shadow = 0.25;}
if((PSInput.uv1.y<biasY-0.0030)||(shdX<biasX-0.0130))
{shadow = 0.30;}
if((PSInput.uv1.y<biasY-0.0035)||(shdX<biasX-0.0150))
{shadow = 0.35;}
if((PSInput.uv1.y<biasY-0.0040)||(shdX<biasX-0.0180))
{shadow = 0.40;}
if((PSInput.uv1.y<biasY-0.0045)||(shdX<biasX-0.0200))
{shadow = 0.45;}
if((PSInput.uv1.y<biasY-0.0050)||(shdX<biasX-0.0230))
{shadow = 0.50;}

diffuse.rgb = diffuse.rgb + lerp(diffuse.rgb*0.1,float3(0.0,0.1,0.1),min(max(saturate(PSInput.fp)*0.4 ,0.0),1.0));

diffuse.rgb = lerp(diffuse.rgb, diffuse.rgb+saturate(PSInput.fp)*float3(0.1,0.1,0.3), FOG_COLOR);

diffuse.rgb = lerp(diffuse.rgb, diffuse.rgb*AS, shadow*noshd2*noshd);
diffuse.rgb = toneMap(diffuse.rgb);
diffuse.rgb *= 1.0 - max(0.0,max(0.0,length(PSInput.s.xy))-0.60);

//diffuse = sunLight( dayLight( moonLight( diffuse, timeMidnight*nolight,night), timeNoon,day), timeSunset,sun);




//float3 normal = normalize(cross(ddx(PSInput.pos),ddy(PSInput.pos)));

//if(normalize(diffuse.rgb*normal).r + 0.0001>0.5){diffuse *=0.5+PSInput.uv1.x;}else if(normalize(diffuse.rgb*normal).g + 0.0001>0.5){diffuse *=0.5+PSInput.uv1.x;}else if(normalize(diffuse.rgb*normal).b + 0.0001>0.5){diffuse *=0.5+PSInput.uv1.x;}else{diffuse *= 1.0;}

#ifdef FOG
	diffuse.rgb = lerp( diffuse.rgb, PSInput.fogColor.rgb, PSInput.fogColor.a );
#endif

	PSOutput.color = diffuse;
	PSOutput.color = sunLight( dayLight( moonLight( PSOutput.color, timeMidnight*nolight,night), timeNoon,day), timeSunset,sun);

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to 
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}