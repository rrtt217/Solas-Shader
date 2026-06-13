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