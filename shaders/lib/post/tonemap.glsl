const mat3 Rec2020_2_sRGB = mat3(
     1.6603034854, -0.5875701425, -0.0728900602,
    -0.1243755953,  1.1328344814, -0.0083597372,
    -0.0181122800, -0.1005836085,  1.1187703262
);

const mat3 sRGB_2_Rec2020 = mat3(
    0.6274413721, 0.3292974595, 0.0433514584,
    0.0690276171, 0.9195806669, 0.0113614226,
    0.0163642351, 0.0880171625, 0.8955649727
);

const mat3 sRGB_2_XYZ = mat3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041
);

const mat3 XYZ_2_sRGB = mat3(
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142
);

const mat3 XYZ_2_Rec2020 = mat3(
     1.716651188,  -0.3556707838, -0.2533662814,
    -0.6666843518,  1.6164812366,  0.0157685458,
     0.0176398574, -0.0427706133,  0.9421031212
);

const mat3 Rec2020_2_XYZ = mat3(
    0.6369580483, 0.1446169036, 0.1688809752,
    0.2627002120, 0.6779980715, 0.0593017165,
    0.0000000000, 0.0280726930, 1.0609850577
);

// https://en.wikipedia.org/wiki/SRGB
// https://github.com/tobspr/GLSL-Color-Spaces/blob/master/ColorSpaces.inc.glsl
vec3 linearToSRGB(in vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(0.41666666)) - 0.055, step(vec3(0.0031308), color));
}

vec3 sRGBToLinear(in vec3 color) {
	return mix(color * 0.07739938, pow((color + 0.055) * 0.94786729, vec3(2.4)), step(vec3(0.04045), color));
}

// https://en.wikipedia.org/wiki/SRGB
// https://en.wikipedia.org/wiki/ScRGB
// -f(-x) for negative values.
vec3 sRGBToLinearSafe(in vec3 color) {
    vec3 color_sign = sign(color);
    vec3 color_abs = abs(color);
	return mix(color_abs * 0.07739938, pow((color_abs + 0.055) * 0.94786729, vec3(2.4)), step(vec3(0.04045), color_abs)) * color_sign;
}

vec3 linearToSRGBSafe(in vec3 color) {
    vec3 color_sign = sign(color);
    vec3 color_abs = abs(color);
	return mix(color_abs * 12.92, 1.055 * pow(color_abs, vec3(0.41666666)) - 0.055, step(vec3(0.0031308), color_abs)) * color_sign;
}


vec3 reinhard(vec3 hdr) {
	return hdr / (1.0 + dot(hdr, vec3(0.299, 0.587, 0.114)));
}

vec3 invReinhard(vec3 sdr) {
	return sdr / (1.0 - dot(sdr, vec3(0.299, 0.587, 0.114)));
}

#ifdef HDR_ENABLED
    //https://github.com/mqhaji/renodx/blob/main/src/games/batmanak/uncharted2extended.hlsli

    float Hable_ApplyCurve(float x, float a, float b, float c, float d, float e, float f) {
        float numerator = x * (a * x + c * b) + d * e;  // x * (a * x + c * b) + d * e
        float denominator = x * (a * x + b) + d * f;    // x * (a * x + b) + d * f
        return (numerator / denominator) - (e / f);
    }

    vec3 Hable_ApplyCurve(vec3 x, float a, float b, float c, float d, float e, float f) {
        vec3 numerator = x * (a * x + c * b) + d * e;  // x * (a * x + c * b) + d * e
        vec3 denominator = x * (a * x + b) + d * f;    // x * (a * x + b) + d * f
        return (numerator / denominator) - (e / f);
    }

    float Hable_InverseUncharted2(
        float y, float W,
        float A, float B, float C, float D, float E, float F) {
        // 1. Recover raw ApplyCurve output: y_raw = y * ApplyCurve(W)
        float rawW = Hable_ApplyCurve(W, A, B, C, D, E, F);
        float y_raw = y * rawW;

        // 2. Solve inverse of ApplyCurve analytically (quadratic)
        float ef = E / F;
        float yp = y_raw + ef;

        // Quadratic coefficients:
        // A_q x^2 + B_q x + C_q = 0
        float A_q = A * (yp - 1.0);
        float B_q = B * (yp - C);
        float C_q = D * (F * yp - E);

        // Quadratic discriminant
        float disc = B_q * B_q - 4.0 * A_q * C_q;
        disc = max(disc, 0.0);
        float sqrtD = sqrt(disc);

        float x1 = (-B_q + sqrtD) / (2.0 * A_q);
        float x2 = (-B_q - sqrtD) / (2.0 * A_q);

        // pick the physically meaningful root (positive, usually x1)
        return max(x1, x2);
    }

    vec3 Hable_InverseUncharted2(
        vec3 color, float W,
        float A, float B, float C, float D, float E, float F) {
    return vec3(
        Hable_InverseUncharted2(color.r, W, A, B, C, D, E, F),
        Hable_InverseUncharted2(color.g, W, A, B, C, D, E, F),
        Hable_InverseUncharted2(color.b, W, A, B, C, D, E, F));
    }

    float Hable_Derivative(
        float x,
        float a, float b, float c,
        float d, float e, float f) {
        float num = -a * b * (c - 1.0) * x * x
                    + 2.0 * a * d * (f - e) * x
                    + b * d * (c * f - e);

        float den = x * (a * x + b) + d * f;
        den = den * den;

        return num / den;
    }

    // Root of f'(x) = 0 for the raw ApplyCurve, using quadratic formula.
    // With a,b,c,d,e,f > 0 and 0 < c < 1, this is well-defined.
    float Hable_FindDerivativeRoot(
        float a, float b, float c,
        float d, float e, float f) {
        // Quadratic coefficients for numerator of f'(x)
        // -a*b*(c - 1) * x^2 + 2*a*d*(f - e)*x + b*d*(c*f - e) = 0
        float Aq = a * b * (1.f - c);  // -a*b*(c-1)
        float Bq = 2.f * a * d * (f - e);
        float Cq = b * d * (c * f - e);

        // Discriminant
        float disc = Bq * Bq - 4.f * Aq * Cq;
        disc = max(disc, 0.f);  // just in case of tiny negatives

        float sqrtDisc = sqrt(disc);

        float r1 = (-Bq + sqrtDisc) / (2.f * Aq);
        float r2 = (-Bq - sqrtDisc) / (2.f * Aq);

        // Larger root of the quadratic
        float root = max(r1, r2);

        // Only care about non-negative x in our domain
        return max(root, 0.f);
    }

    // Analytic knee root of f'''(x) = 0 for Uncharted2/Hable ApplyCurve
    // a,b,c,d,e,f > 0, typically 0 < c < 1.
    // Returns the smallest positive real root ("first knee") in x > 0.
    float Hable_FindThirdDerivativeRoot(float a, float b, float c, float d, float e, float f) {
        // sqrt(a b^2 c^2 - 2 a b^2 c + a b^2)
        float sqrt_ab = sqrt(
            a * b * b * c * c
            - 2.f * a * b * b * c
            + a * b * b);

        // sqrt(a d^2 e^2 - 2 a d^2 e f + a d^2 f^2
        //    + b^2 c^2 d f + b^2 (-c) d e - b^2 c d f + b^2 d e)
        float sqrt_df = sqrt(
            a * d * d * e * e
            - 2.f * a * d * d * e * f
            + a * d * d * f * f
            + b * b * c * c * d * f
            + b * b * (-c) * d * e
            - b * b * c * d * f
            + b * b * d * e);

        // Precompute (d e - d f)
        float de_df = d * e - d * f;

        // Inner big piece: sqrt_ab * (...) / (8 * sqrt_df)
        float term_top =
            32.f * (a * d * d * e * f - a * d * d * f * f + b * b * c * d * f - b * b * d * e)
            / (a * a * b * (c - 1.f));

        float term_mid =
            96.f * de_df * (c * d * f - d * e)
            / (a * b * (c - 1.f) * (c - 1.f));

        float de_df2 = de_df * de_df;
        float de_df3 = de_df2 * de_df;

        float term_tail =
            64.f * de_df3
            / (b * b * b * (c - 1.f) * (c - 1.f) * (c - 1.f));

        float Tfrac = sqrt_ab * (term_top - term_mid - term_tail)
                        / (8.f * sqrt_df);

        // (12 a^2 b c d f - 12 a^2 b d e) / (6 (a^3 b c - a^3 b))
        float Tmid2_num = 12.f * a * a * b * c * d * f
                            - 12.f * a * a * b * d * e;
        float Tmid2_den = 6.f * (a * a * a * b * c - a * a * a * b);
        float Tmid2 = Tmid2_num / Tmid2_den;

        // (6 (c d f - d e))/(a (c - 1))
        float T3 = 6.f * (c * d * f - d * e)
                    / (a * (c - 1.f));

        // (8 (d e - d f)^2)/(b^2 (c - 1)^2)
        float T4 = 8.f * de_df2
                    / (b * b * (c - 1.f) * (c - 1.f));

        // Centers for the ± branches
        float centerNeg = -Tfrac + Tmid2 + T3 + T4;  // used with sqrt(-centerNeg)
        float centerPos = Tfrac + Tmid2 + T3 + T4;   // used with sqrt( centerPos)

        // Branch square roots: use SignSqrt for robustness and correct branch behaviour
        float sNeg = sign(centerNeg) * sqrt(abs(centerNeg));
        float sPos = sign(centerPos) * sqrt(abs(centerPos));

        // Shifts:
        //  - first two roots use:  - sqrt_df/sqrt_ab - (d e - d f)/(b (c - 1))
        //  - last two use:          sqrt_df/sqrt_ab - (d e - d f)/(b (c - 1))
        float shift1 = sqrt_df / sqrt_ab + de_df / (b * (c - 1.f));  // we subtract this
        float shift2 = sqrt_df / sqrt_ab - de_df / (b * (c - 1.f));  // we add this

        // The four analytic roots from WA, mapped to floats:
        float r1 = -0.5f * sNeg - shift1;  // -1/2 * sqrt(-centerNeg) - shift1
        float r2 = 0.5f * sNeg - shift1;   //  1/2 * sqrt(-centerNeg) - shift1
        float r3 = -0.5f * sPos + shift2;  // -1/2 * sqrt( centerPos) + shift2
        float r4 = 0.5f * sPos + shift2;   //  1/2 * sqrt( centerPos) + shift2

        // Max root seems to be always be the right one
        float root = clamp(max(r1, max(r2, max(r3, r4))), 0, 1);

        return root;
    }

    struct Hable_Uncharted2ExtendedConfig {
        float pivot_point;
        float white_precompute;
        float coeffs[6];  // A,B,C,D,E,F
    };

    Hable_Uncharted2ExtendedConfig Hable_CreateUncharted2ExtendedConfig(
        float pivot_point,
        float coeffs[6], float white_precompute) {
        Hable_Uncharted2ExtendedConfig cfg;
        cfg.pivot_point = pivot_point;
        cfg.white_precompute = white_precompute;
        cfg.coeffs = coeffs;

        return cfg;
    }

    Hable_Uncharted2ExtendedConfig Hable_CreateUncharted2ExtendedConfig(float coeffs[6], float white_precompute) {
    float pivot_point = Hable_FindThirdDerivativeRoot(coeffs[0], coeffs[1], coeffs[2], coeffs[3], coeffs[4], coeffs[5]);
        return Hable_CreateUncharted2ExtendedConfig(pivot_point, coeffs, white_precompute);
    }

    float Hable_ApplyExtended(                                                                             
        float x, float base, float pivot_point, float white_precompute,
        float A, float B, float C, float D, float E, float F) {                                  
        float pivot_x = pivot_point;
        float pivot_y = Hable_ApplyCurve(pivot_x, A, B, C, D, E, F) * white_precompute;
        float slope = Hable_Derivative(pivot_x, A, B, C, D, E, F) * white_precompute;
        float offset = pivot_y - slope * pivot_x;

        float extended = slope * x + offset; 

        return mix(base, extended, step(pivot_x, x));
    }
    float Hable_ApplyExtended(float x, float base, Hable_Uncharted2ExtendedConfig uc2_config) {
        return Hable_ApplyExtended(
            x, base, uc2_config.pivot_point, uc2_config.white_precompute,
            uc2_config.coeffs[0], uc2_config.coeffs[1], uc2_config.coeffs[2],
            uc2_config.coeffs[3], uc2_config.coeffs[4], uc2_config.coeffs[5]);
    }
    float Hable_ApplyExtended(float x, Hable_Uncharted2ExtendedConfig uc2_config) {
        float base =
            Hable_ApplyCurve(x, uc2_config.coeffs[0], uc2_config.coeffs[1], uc2_config.coeffs[2],
                                        uc2_config.coeffs[3], uc2_config.coeffs[4], uc2_config.coeffs[5])
            * uc2_config.white_precompute;
        return Hable_ApplyExtended(x, base, uc2_config);
    }

    vec3 Hable_ApplyExtended(                                                                             
        vec3 x, vec3 base, float pivot_point, float white_precompute,
        float A, float B, float C, float D, float E, float F) {                                  
        float pivot_x = pivot_point;
        float pivot_y = Hable_ApplyCurve(pivot_x, A, B, C, D, E, F) * white_precompute;
        float slope = Hable_Derivative(pivot_x, A, B, C, D, E, F) * white_precompute;
        vec3 offset = vec3(pivot_y - slope * pivot_x);

        vec3 extended = vec3(slope) * x + offset;

        return mix(base, extended, step(vec3(pivot_x), x));
    }
    vec3 Hable_ApplyExtended(vec3 x, vec3 base, Hable_Uncharted2ExtendedConfig uc2_config) {
        return Hable_ApplyExtended(
            x, base, uc2_config.pivot_point, uc2_config.white_precompute,
            uc2_config.coeffs[0], uc2_config.coeffs[1], uc2_config.coeffs[2],
            uc2_config.coeffs[3], uc2_config.coeffs[4], uc2_config.coeffs[5]);
    }
    vec3 Hable_ApplyExtended(vec3 x, Hable_Uncharted2ExtendedConfig uc2_config) {
        vec3 base =
            Hable_ApplyCurve(x, uc2_config.coeffs[0], uc2_config.coeffs[1], uc2_config.coeffs[2],
                                        uc2_config.coeffs[3], uc2_config.coeffs[4], uc2_config.coeffs[5])
            * uc2_config.white_precompute;
        return Hable_ApplyExtended(x, base, uc2_config);
    }

    vec3 Reinhard(vec3 x, float peak) {
        return x / (x / peak + 1.0);
    }
    vec3 ReinhardExtended(vec3 x, float white_max, float peak) {
        return Reinhard(x, peak) * (1.0 + (peak * x) / (white_max * white_max));
    }
    float ComputeReinhardExtendableScale(float w, float p, float m, float x, float y) {
        return p * (w * w * y - (p * x * x)) / (w * w * x * (p - y));
    }
    vec3 ReinhardPiecewiseExtended(vec3 x, float white_max, float x_max, float shoulder)
    {
        const float x_min = 0.0f;
        float exposure = ComputeReinhardExtendableScale(white_max, x_max, x_min, shoulder, shoulder);
        vec3 extended = ReinhardExtended(x * exposure, white_max * exposure, x_max);
        extended = min(extended, x_max);
        return mix(x, extended, step(shoulder, x));
    }

    vec3 Uncharted2Tonemap(vec3 x) {
        const float A = TONEMAP_HIGHLIGHTS;
        const float B = 0.20;
        const float C = TONEMAP_SHADOWS;
        const float D = 0.15;
        float E = 0.01 * TONEMAP_CONTRAST;
        const float F = 0.35;
        const float W = TONEMAP_WHITE_THRESHOLD;
        float[6] coeffs = float[6](A, B, C, D, E, F);
        float white_precompute = 1.f / Hable_ApplyCurve(W, A, B, C, D, E, F);
        Hable_Uncharted2ExtendedConfig uc2_config = Hable_CreateUncharted2ExtendedConfig(coeffs, white_precompute);
        x = Hable_ApplyExtended(abs(x), uc2_config) * sign(x);
        return ReinhardPiecewiseExtended(x, 100, HdrGamePeakBrightness / HdrGamePaperWhiteBrightness, 36.0 / HdrGamePaperWhiteBrightness);
    }
    vec3 Uncharted2OriginalTonemap(vec3 x) {
        const float A = TONEMAP_HIGHLIGHTS;
        const float B = 0.20;
        const float C = TONEMAP_SHADOWS;
        const float D = 0.15;
        float E = 0.01 * TONEMAP_CONTRAST;
        const float F = 0.35;

        return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
    }
#else
    vec3 Uncharted2Tonemap(vec3 x) {
        const float A = TONEMAP_HIGHLIGHTS;
        const float B = 0.20;
        const float C = TONEMAP_SHADOWS;
        const float D = 0.15;
        float E = 0.01 * TONEMAP_CONTRAST;
        const float F = 0.35;

        return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
    }
    #define Uncharted2OriginalTonemap Uncharted2Tonemap
#endif

// allenwp tonemapping curve; developed for use in the Godot game engine.
// Source and details: https://allenwp.com/blog/2025/05/29/allenwp-tonemapping-curve/
// Input must be a non-negative linear scene value.
vec3 allenwp_curve(vec3 x) {
    #ifdef HDR_ENABLED
        float output_max_value = HdrGamePeakBrightness / HdrGamePaperWhiteBrightness;
    #else
        float output_max_value = 1.0;
    #endif
	// These constants must match the those in the C++ code that calculates the parameters.
	// 18% "middle gray" is perceptually 50% of the brightness of reference white.
	const float awp_crossover_point = 0.1841865;
	float awp_shoulder_max = output_max_value - awp_crossover_point;
    float awp_high_clip = 12.0;
    awp_high_clip = max(awp_high_clip, output_max_value);
	float awp_contrast = 1.5;
	float awp_toe_a = ((1.0 / awp_crossover_point) - 1.0) * pow(awp_crossover_point, awp_contrast);
    float awp_slope_denom = pow(awp_crossover_point, awp_contrast) + awp_toe_a;
	float awp_slope = (awp_contrast * pow(awp_crossover_point, awp_contrast - 1.0) * awp_toe_a) / (awp_slope_denom * awp_slope_denom);
	float awp_w = awp_high_clip - awp_crossover_point;
	awp_w = awp_w * awp_w;
	awp_w = awp_w / awp_shoulder_max;
	awp_w = awp_w * awp_slope;

	// Reinhard-like shoulder:
	vec3 s = x - awp_crossover_point;
	vec3 slope_s = awp_slope * s;
	s = slope_s * (1.0 + s / awp_w) / (1.0 + (slope_s / awp_shoulder_max));
	s += awp_crossover_point;

	// Sigmoid power function toe:
	vec3 t = pow(x, vec3(awp_contrast));
	t = t / (t + awp_toe_a);

	return mix(s, t, lessThan(x, vec3(awp_crossover_point)));
}

// This is an approximation and simplification of EaryChow's AgX implementation that is used by Blender.
// This code is based off of the script that generates the AgX_Base_sRGB.cube LUT that Blender uses.
// Source: https://github.com/EaryChow/AgX_LUT_Gen/blob/main/AgXBasesRGB.py
// Colorspace transformation source: https://www.colour-science.org:8010/apps/rgb_colourspace_transformation_matrix
vec3 AgXAllenwpTonemap(vec3 color) {
	// Input color should be non-negative!
	// Large negative values in one channel and large positive values in other
	// channels can result in a colour that appears darker and more saturated than
	// desired after passing it through the inset matrix. For this reason, it is
	// best to prevent negative input values.
	// This is done before the Rec. 2020 transform to allow the Rec. 2020
	// transform to be combined with the AgX inset matrix. This results in a loss
	// of color information that could be correctly interpreted within the
	// Rec. 2020 color space as positive RGB values, but is often not worth
	// the performance cost of an additional matrix multiplication.
	//
	// Additionally, this AgX configuration was created subjectively based on
	// output appearance in the Rec. 709 color gamut, so it is possible that these
	// matrices will not perform well with non-Rec. 709 output (more testing with
	// future wide-gamut displays is be needed).
	// See this comment from the author on the decisions made to create the matrices:
	// https://github.com/godotengine/godot-proposals/issues/12317#issuecomment-2835824250

	// Combined Rec. 709 to Rec. 2020 and Blender AgX inset matrices:
	const mat3 rec709_to_rec2020_agx_inset_matrix = mat3(
			0.544814746488245, 0.140416948464053, 0.0888104196149096,
			0.373787398372697, 0.754137554567394, 0.178871756420858,
			0.0813978551390581, 0.105445496968552, 0.732317823964232);

	// Combined inverse AgX outset matrix and Rec. 2020 to Rec. 709 matrices.
	const mat3 agx_outset_rec2020_to_rec709_matrix = mat3(
			1.96488741169489, -0.299313364904742, -0.164352742528393,
			-0.855988495690215, 1.32639796461980, -0.238183969428088,
			-0.108898916004672, -0.0270845997150571, 1.40253671195648);
    #ifdef HDR_ENABLED
	    float output_max_value = HdrGamePeakBrightness / HdrGamePaperWhiteBrightness;
    #else
        float output_max_value = 1.0;
    #endif

    // Apply inset matrix.
	color = rec709_to_rec2020_agx_inset_matrix * color;

	// Use the allenwp tonemapping curve to match the Blender AgX curve while
	// providing stability across all variable dyanimc range (SDR, HDR, EDR).
	color = allenwp_curve(color);

	// Clipping to output_max_value is required to address a cyan colour that occurs
	// with very bright inputs.
	color = min(vec3(output_max_value), color);

	// Apply outset to make the result more chroma-laden and then go back to Rec. 709.
	color = agx_outset_rec2020_to_rec709_matrix * color;

	// Blender's lusRGB.compensate_low_side is too complex for this shader, so
	// simply return the color, even if it has negative components. These negative
	// components may be useful for subsequent color adjustments.
    return color;
}

// Uchimura 2017, "HDR theory and practice"
// Math: https://www.desmos.com/calculator/gslcdxvipg
// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
vec3 GTTonemap(in vec3 x) {
    #ifdef HDR_ENABLED
        float maxDisplayBrightness = HdrGamePeakBrightness / HdrGamePaperWhiteBrightness;
    #else
        const float maxDisplayBrightness = 1.0;
    #endif
    const float contrast			 = 1.0;
    const float linearStart			 = 0.2;
    const float linearLength		 = 0.1;
    const float black				 = 1.33;
    const float pedestal			 = 0.0;

    float l0 = ((maxDisplayBrightness - linearStart) * linearLength) / contrast;
    const float L0 = linearStart - linearStart / contrast;
    const float L1 = linearStart + (1.0 - linearStart) / contrast;
    float S0 = linearStart + l0;
    float S1 = linearStart + contrast * l0;
    float C2 = contrast * maxDisplayBrightness / (maxDisplayBrightness - S1);
    float CP = -1.44269502 * C2 / maxDisplayBrightness;

    vec3 w0 = 1.0 - smoothstep(0.0, linearStart, x);
    vec3 w2 = step(S0, x);
    vec3 w1 = 1.0 - w0 - w2;

    vec3 T = pow(x, vec3(black)) / pow(linearStart, black - 1.0) + pedestal;
    vec3 S = maxDisplayBrightness - (maxDisplayBrightness - S1) * exp2(CP * (x - S0));
    vec3 L = linearStart + contrast * (x - linearStart);

	return T * w0 + L * w1 + S * w2;
}

// Source: https://blog.selfshadow.com/publications/s2025-shading-course/pdi/supplemental/gt7_tone_mapping.cpp

// MIT License
//
// Copyright (c) 2025 Polyphony Digital Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// -----------------------------------------------------------------------------
// Mode options.
// -----------------------------------------------------------------------------
#define TONE_MAPPING_UCS_ICTCP  0
#define TONE_MAPPING_UCS_JZAZBZ 1
#define TONE_MAPPING_UCS        TONE_MAPPING_UCS_ICTCP

// -----------------------------------------------------------------------------
// Defines the SDR reference white level used in our tone mapping (typically 250 nits).
// -----------------------------------------------------------------------------
#define GRAN_TURISMO_SDR_PAPER_WHITE 250.0f // cd/m^2

// -----------------------------------------------------------------------------
// Gran Turismo luminance-scale conversion helpers.
// In Gran Turismo, 1.0f in the linear frame-buffer space corresponds to
// REFERENCE_LUMINANCE cd/m^2 of physical luminance (typically 100 cd/m^2).
// -----------------------------------------------------------------------------
#define REFERENCE_LUMINANCE 100.0f // cd/m^2 <-> 1.0f

float
frameBufferValueToPhysicalValue(float fbValue)
{
    // Converts linear frame-buffer value to physical luminance (cd/m^2)
    // where 1.0 corresponds to REFERENCE_LUMINANCE (e.g., 100 cd/m^2).
    return fbValue * REFERENCE_LUMINANCE;
}

float
physicalValueToFrameBufferValue(float physical)
{
    // Converts physical luminance (cd/m^2) to a linear frame-buffer value,
    // where 1.0 corresponds to REFERENCE_LUMINANCE (e.g., 100 cd/m^2).
    return physical / REFERENCE_LUMINANCE;
}

// -----------------------------------------------------------------------------
// Utility functions.
// -----------------------------------------------------------------------------
float
smoothStep(float x, float edge0, float edge1)
{
    float t = (x - edge0) / (edge1 - edge0);

    if (x < edge0)
    {
        return 0.0f;
    }
    if (x > edge1)
    {
        return 1.0f;
    }

    return t * t * (3.0f - 2.0f * t);
}

float
chromaCurve(float x, float a, float b)
{
    return 1.0f - smoothStep(x, a, b);
}

// -----------------------------------------------------------------------------
// "GT Tone Mapping" curve with convergent shoulder.
// -----------------------------------------------------------------------------
struct GTToneMappingCurveV2
{
    float peakIntensity_;
    float alpha_;
    float midPoint_;
    float linearSection_;
    float toeStrength_;
    float kA_, kB_, kC_;
};

void initializeCurve(float monitorIntensity,
                        float alpha,
                        float grayPoint,
                        float linearSection,
                        float toeStrength,
                        inout GTToneMappingCurveV2 curve)
{
    curve.peakIntensity_ = monitorIntensity;
    curve.alpha_         = alpha;
    curve.midPoint_      = grayPoint;
    curve.linearSection_ = linearSection;
    curve.toeStrength_   = toeStrength;

    // Pre-compute constants for the shoulder region.
    float k = (curve.linearSection_ - 1.0f) / (curve.alpha_ - 1.0f);
    curve.kA_     = curve.peakIntensity_ * curve.linearSection_ + curve.peakIntensity_ * k;
    curve.kB_     = -curve.peakIntensity_ * k * exp(curve.linearSection_ / k);
    curve.kC_     = -1.0f / (k * curve.peakIntensity_);
}

float evaluateCurve(float x, GTToneMappingCurveV2 curve)
{
    if (x < 0.0f)
    {
        return 0.0f;
    }

    float weightLinear = smoothStep(x, 0.0f, curve.midPoint_);
    float weightToe    = 1.0f - weightLinear;

    // Shoulder mapping for highlights.
    float shoulder = curve.kA_ + curve.kB_ * exp(x * curve.kC_);

    if (x < curve.linearSection_ * curve.peakIntensity_)
    {
        float toeMapped = curve.midPoint_ * pow(x / curve.midPoint_, curve.toeStrength_);
        return weightToe * toeMapped + weightLinear * x;
    }
    else
    {
        return shoulder;
    }
}

// -----------------------------------------------------------------------------
// EOTF / inverse-EOTF for ST-2084 (PQ).
// Note: Introduce exponentScaleFactor to allow scaling of the exponent in the EOTF for Jzazbz.
// -----------------------------------------------------------------------------
float
eotfSt2084(float n, float exponentScaleFactor)
{
    if (n < 0.0f)
    {
        n = 0.0f;
    }
    if (n > 1.0f)
    {
        n = 1.0f;
    }

    // Base functions from SMPTE ST 2084:2014
    // Converts from normalized PQ (0-1) to absolute luminance in cd/m^2 (linear light)
    // Assumes float input; does not handle integer encoding (Annex)
    // Assumes full-range signal (0-1)
    const float m1  = 0.1593017578125f;                // (2610 / 4096) / 4
    float m2  = 78.84375f * exponentScaleFactor; // (2523 / 4096) * 128
    const float c1  = 0.8359375f;                      // 3424 / 4096
    const float c2  = 18.8515625f;                     // (2413 / 4096) * 32
    const float c3  = 18.6875f;                        // (2392 / 4096) * 32
    const float pqC = 10000.0f;                        // Maximum luminance supported by PQ (cd/m^2)

    // Does not handle signal range from 2084 - assumes full range (0-1)
    float np = pow(n, 1.0f / m2);
    float l  = np - c1;

    if (l < 0.0f)
    {
        l = 0.0f;
    }

    l = l / (c2 - c3 * np);
    l = pow(l, 1.0f / m1);

    // Convert absolute luminance (cd/m^2) into the frame-buffer linear scale.
    return physicalValueToFrameBufferValue(l * pqC);
}

float
inverseEotfSt2084(float v, float exponentScaleFactor)
{
    const float m1  = 0.1593017578125f;
    float m2  = 78.84375f * exponentScaleFactor;
    const float c1  = 0.8359375f;
    const float c2  = 18.8515625f;
    const float c3  = 18.6875f;
    const float pqC = 10000.0f;

    // Convert the frame-buffer linear scale into absolute luminance (cd/m^2).
    float physical = frameBufferValueToPhysicalValue(v);
    float y        = physical / pqC; // Normalize for the ST-2084 curve

    float ym = pow(y, m1);
    return exp2(m2 * (log2(c1 + c2 * ym) - log2(1.0f + c3 * ym)));
}

// -----------------------------------------------------------------------------
// ICtCp conversion.
// Reference: ITU-T T.302 (https://www.itu.int/rec/T-REC-T.302/en)
// -----------------------------------------------------------------------------
void
rgbToICtCp(vec3 rgb, inout vec3 ictCp) // Input: linear Rec.2020
{
    float l = (rgb[0] * 1688.0f + rgb[1] * 2146.0f + rgb[2] * 262.0f) / 4096.0f;
    float m = (rgb[0] * 683.0f + rgb[1] * 2951.0f + rgb[2] * 462.0f) / 4096.0f;
    float s = (rgb[0] * 99.0f + rgb[1] * 309.0f + rgb[2] * 3688.0f) / 4096.0f;

    float lPQ = inverseEotfSt2084(l, 1.0);
    float mPQ = inverseEotfSt2084(m, 1.0);
    float sPQ = inverseEotfSt2084(s, 1.0);

    ictCp[0] = (2048.0f * lPQ + 2048.0f * mPQ) / 4096.0f;
    ictCp[1] = (6610.0f * lPQ - 13613.0f * mPQ + 7003.0f * sPQ) / 4096.0f;
    ictCp[2] = (17933.0f * lPQ - 17390.0f * mPQ - 543.0f * sPQ) / 4096.0f;
}

void
iCtCpToRgb(vec3 ictCp, inout vec3 rgb) // Output: linear Rec.2020
{
    float l = ictCp[0] + 0.00860904f * ictCp[1] + 0.11103f * ictCp[2];
    float m = ictCp[0] - 0.00860904f * ictCp[1] - 0.11103f * ictCp[2];
    float s = ictCp[0] + 0.560031f * ictCp[1] - 0.320627f * ictCp[2];

    float lLin = eotfSt2084(l, 1.0);
    float mLin = eotfSt2084(m, 1.0);
    float sLin = eotfSt2084(s, 1.0);

    rgb[0] = max(3.43661f * lLin - 2.50645f * mLin + 0.0698454f * sLin, 0.0f);
    rgb[1] = max(-0.79133f * lLin + 1.9836f * mLin - 0.192271f * sLin, 0.0f);
    rgb[2] = max(-0.0259499f * lLin - 0.0989137f * mLin + 1.12486f * sLin, 0.0f);
}

// -----------------------------------------------------------------------------
// Jzazbz conversion.
// Reference:
// Muhammad Safdar, Guihua Cui, Youn Jin Kim, and Ming Ronnier Luo,
// "Perceptually uniform color space for image signals including high dynamic
// range and wide gamut," Opt. Express 25, 15131-15151 (2017)
// Note: Coefficients adjusted for linear Rec.2020
// -----------------------------------------------------------------------------
#define JZAZBZ_EXPONENT_SCALE_FACTOR 1.7f // Scale factor for exponent

void
rgbToJzazbz(vec3 rgb, inout vec3 jab) // Input: linear Rec.2020
{
    float l = rgb[0] * 0.530004f + rgb[1] * 0.355704f + rgb[2] * 0.086090f;
    float m = rgb[0] * 0.289388f + rgb[1] * 0.525395f + rgb[2] * 0.157481f;
    float s = rgb[0] * 0.091098f + rgb[1] * 0.147588f + rgb[2] * 0.734234f;

    float lPQ = inverseEotfSt2084(l, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float mPQ = inverseEotfSt2084(m, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float sPQ = inverseEotfSt2084(s, JZAZBZ_EXPONENT_SCALE_FACTOR);

    float iz = 0.5f * lPQ + 0.5f * mPQ;

    jab[0] = (0.44f * iz) / (1.0f - 0.56f * iz) - 1.6295499532821566e-11f;
    jab[1] = 3.524000f * lPQ - 4.066708f * mPQ + 0.542708f * sPQ;
    jab[2] = 0.199076f * lPQ + 1.096799f * mPQ - 1.295875f * sPQ;
}

void
jzazbzToRgb(vec3 jab, inout vec3 rgb) // Output: linear Rec.2020
{
    float jz = jab[0] + 1.6295499532821566e-11f;
    float iz = jz / (0.44f + 0.56f * jz);
    float a  = jab[1];
    float b  = jab[2];

    float l = iz + a * 1.386050432715393e-1f + b * 5.804731615611869e-2f;
    float m = iz + a * -1.386050432715393e-1f + b * -5.804731615611869e-2f;
    float s = iz + a * -9.601924202631895e-2f + b * -8.118918960560390e-1f;

    float lLin = eotfSt2084(l, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float mLin = eotfSt2084(m, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float sLin = eotfSt2084(s, JZAZBZ_EXPONENT_SCALE_FACTOR);

    rgb[0] = lLin * 2.990669f + mLin * -2.049742f + sLin * 0.088977f;
    rgb[1] = lLin * -1.634525f + mLin * 3.145627f + sLin * -0.483037f;
    rgb[2] = lLin * -0.042505f + mLin * -0.377983f + sLin * 1.448019f;
}

// -----------------------------------------------------------------------------
// Unified color space (UCS): ICtCp or Jzazbz.
// -----------------------------------------------------------------------------
#if TONE_MAPPING_UCS == TONE_MAPPING_UCS_ICTCP
#define rgbToUcs rgbToICtCp
#define ucsToRgb iCtCpToRgb
#elif TONE_MAPPING_UCS == TONE_MAPPING_UCS_JZAZBZ
#define rgbToUcs rgbToJzazbz
#define ucsToRgb jzazbzToRgb
#else
#error "Unsupported TONE_MAPPING_UCS value. Please define TONE_MAPPING_UCS as either TONE_MAPPING_UCS_ICTCP or TONE_MAPPING_UCS_JZAZBZ."
#endif

// -----------------------------------------------------------------------------
// GT7 Tone Mapping class.
// -----------------------------------------------------------------------------
struct GT7ToneMapping
{
    float sdrCorrectionFactor_;

    float framebufferLuminanceTarget_;
    float framebufferLuminanceTargetUcs_; // Target luminance in UCS space
    GTToneMappingCurveV2 curve_;

    float blendRatio_;
    float fadeStart_;
    float fadeEnd_;
};

// Initializes the tone mapping curve and related parameters based on the target display luminance.
// This method should not be called directly. Use initializeAsHDR() or initializeAsSDR() instead.
void initializeParameters(float physicalTargetLuminance, inout GT7ToneMapping tm)
{
    tm.framebufferLuminanceTarget_ = physicalValueToFrameBufferValue(physicalTargetLuminance);

    // Initialize the curve (slightly different parameters from GT Sport).
    initializeCurve(tm.framebufferLuminanceTarget_, 0.25f, 0.538f, 0.444f, 1.280f, tm.curve_);

    // Default parameters.
    tm.blendRatio_ = 0.6f;
    tm.fadeStart_  = 0.98f;
    tm.fadeEnd_    = 1.16f;

    vec3 ucs;
    vec3 rgb = vec3( tm.framebufferLuminanceTarget_,
                     tm.framebufferLuminanceTarget_,
                     tm.framebufferLuminanceTarget_ );
    rgbToUcs(rgb, ucs);
    tm.framebufferLuminanceTargetUcs_ = ucs[0]; // Use the first UCS component (I or Jz) as luminance
}

// Initialize for HDR (High Dynamic Range) display.
// Input: target display peak luminance in nits (range: 250 to 10,000)
// Note: The lower limit is 250 because the parameters for GTToneMappingCurveV2
//       were determined based on an SDR paper white assumption of 250 nits (GRAN_TURISMO_SDR_PAPER_WHITE).
void initializeAsHDR(float physicalTargetLuminance, inout GT7ToneMapping tm)
{
    tm.sdrCorrectionFactor_ = 1.0f;
    initializeParameters(physicalTargetLuminance, tm);
}

// Initialize for SDR (Standard Dynamic Range) display.
void initializeAsSDR(inout GT7ToneMapping tm)
{

    tm.sdrCorrectionFactor_ = 1.0f / physicalValueToFrameBufferValue(GRAN_TURISMO_SDR_PAPER_WHITE);
    initializeParameters(GRAN_TURISMO_SDR_PAPER_WHITE, tm);
}

// Input:  linear Rec.2020 RGB (frame buffer values)
// Output: tone-mapped RGB (frame buffer values);
//         - in SDR mode: mapped to [0, 1], ready for sRGB OETF
//         - in HDR mode: mapped to [0, framebufferLuminanceTarget_], ready for PQ inverse-EOTF
// Note: framebufferLuminanceTarget_ represents the display's target peak luminance converted to a frame buffer value.
//       The returned values are suitable for applying the appropriate OETF to generate final output signal.
void applyToneMapping(inout vec3 rgb, GT7ToneMapping tm)
{
    // Convert to UCS to separate luminance and chroma.
    vec3 ucs;
    rgbToUcs(rgb, ucs);

    // Per-channel tone mapping ("skewed" color).
    vec3 skewedRgb = vec3( evaluateCurve(rgb[0], tm.curve_),
                           evaluateCurve(rgb[1], tm.curve_),
                           evaluateCurve(rgb[2], tm.curve_));

    vec3 skewedUcs;
    rgbToUcs(skewedRgb, skewedUcs);

    float chromaScale =
        chromaCurve(ucs[0] / tm.framebufferLuminanceTargetUcs_, tm.fadeStart_, tm.fadeEnd_);

    vec3 scaledUcs = vec3(skewedUcs[0],         // Luminance from skewed color
                          ucs[1] * chromaScale, // Scaled chroma components
                          ucs[2] * chromaScale);

    // Convert back to RGB.
    vec3 scaledRgb;
    ucsToRgb(scaledUcs, scaledRgb);

    // Final blend between per-channel and UCS-scaled results.
    vec3 blended = (1.0f - tm.blendRatio_) * skewedRgb + tm.blendRatio_ * scaledRgb;
    // When using SDR, apply the correction factor.
    // When using HDR, sdrCorrectionFactor_ is 1.0f, so it has no effect.
    rgb = tm.sdrCorrectionFactor_ * min(blended, tm.framebufferLuminanceTarget_);
}

vec3 GT7Tonemap(in vec3 color) {
    color *= 2.0;
    color *= sRGB_2_Rec2020;

    GT7ToneMapping tm;
    #ifdef HDR_ENABLED
        initializeAsHDR(HdrGamePeakBrightness,tm);
    #else
        initializeAsSDR(tm);
    #endif

    applyToneMapping(color, tm);

    return color * Rec2020_2_sRGB;
}

void colorSaturation(inout vec3 color) {
	float grayVibrance = (color.r + color.g + color.b) / 3.0;
	float graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

	float mn = min(color.r, min(color.g, color.b));
	float mx = max(color.r, max(color.g, color.b));
	float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
	vec3 lightness = vec3((mn + mx) * 0.5);

	color = mix(color, mix(color, lightness, 1.0 - VIBRANCE), sat);
	color = mix(color, lightness, (1.0 - lightness) * (2.0 - VIBRANCE) / 2.0 * abs(VIBRANCE - 1.0));
	color = color * SATURATION - graySaturation * (SATURATION - 1.0);
}