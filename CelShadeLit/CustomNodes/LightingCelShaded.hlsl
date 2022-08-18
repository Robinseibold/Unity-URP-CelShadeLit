#ifndef LIGHTING_CEL_SHADED_INCLUDED
#define LIGHTING_CEL_SHADED_INCLUDED

#ifndef SHADERGRAPH_PREVIEW
struct EdgeConstants {

   float diffuse;
   float specular;
   float rim;
   float distanceAttenuation;
   float shadowAttenuation;

};

struct SurfaceVariables {

   float smoothness;
   float shininess;
   
   float rimStrength;
   float rimAmount;
   float rimThreshold;
   
   float3 normal;
   float3 view;

   EdgeConstants ec;

};

float3 CalculateCelShading(Light l, SurfaceVariables s) {
   float attenuation = 
      smoothstep(0.0f, s.ec.distanceAttenuation, l.distanceAttenuation) * 
      smoothstep(0.0f, s.ec.shadowAttenuation, l.shadowAttenuation);

   float diffuse = saturate(dot(s.normal, l.direction));
   diffuse *= attenuation;

   float3 h = SafeNormalize(l.direction + s.view);
   float specular = saturate(dot(s.normal, h));
   specular = pow(specular, s.shininess);
   specular *= diffuse;

   float rim = 1 - dot(s.view, s.normal);
   rim *= pow(diffuse, s.rimThreshold);

   diffuse = smoothstep(0.0f, s.ec.diffuse, diffuse);
   specular = s.smoothness * smoothstep(0.005f, 
      0.005f + s.ec.specular * s.smoothness, specular);
   rim = s.rimStrength * smoothstep(
      s.rimAmount - 0.5f * s.ec.rim, 
      s.rimAmount + 0.5f * s.ec.rim, 
      rim
   );

   return l.color * (diffuse + max(specular, rim));
}
#endif

void LightingCelShaded_float(float Smoothness, 
      float RimStrength, float RimAmount, float RimThreshold, 
      float3 Position, float3 Normal, float3 View, float EdgeDiffuse,
      float EdgeSpecular, float EdgeDistanceAttenuation,
      float EdgeShadowAttenuation, float EdgeRim, out float3 Color) {

#if defined(SHADERGRAPH_PREVIEW)
   Color = half3(0.5f, 0.5f, 0.5f);
#else
   SurfaceVariables s;
   s.smoothness = Smoothness;
   s.shininess = exp2(10 * Smoothness + 1);
   s.rimStrength = RimStrength;
   s.rimAmount = RimAmount;
   s.rimThreshold = RimThreshold;
   s.normal = normalize(Normal);
   s.view = SafeNormalize(View);
   s.ec.diffuse = EdgeDiffuse;
   s.ec.specular = EdgeSpecular;
   s.ec.distanceAttenuation = EdgeDistanceAttenuation;
   s.ec.shadowAttenuation = EdgeShadowAttenuation;
   s.ec.rim = EdgeRim;

#if SHADOWS_SCREEN
   float4 clipPos = TransformWorldToHClip(Position);
   float4 shadowCoord = ComputeScreenPos(clipPos);
#else
   float4 shadowCoord = TransformWorldToShadowCoord(Position);
#endif

   Light light = GetMainLight(shadowCoord);
   Color = CalculateCelShading(light, s);

   int pixelLightCount = GetAdditionalLightsCount();
   for (int i = 0; i < pixelLightCount; i++) {
      light = GetAdditionalLight(i, Position, 1);
      Color += CalculateCelShading(light, s);
   }
   
#endif
}

#endif