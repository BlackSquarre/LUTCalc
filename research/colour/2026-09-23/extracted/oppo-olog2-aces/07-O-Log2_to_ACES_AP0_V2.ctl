// O-Log2 REC2020 to ACES AP0 CTL

// OLog2 Curve Encoding Function
float relativeSceneLinearToNormalizedOLog2( float x) {
	return (0.0855 * log(x + 0.0096) / log(2.0) + 0.693);
}

// OLog2 Curve Decoding Function
float normalizedOLog2ToRelativeSceneLinear( float x) {
	return (exp((x - 0.693) / 0.0855 * log(2.0)) - 0.0096);
}

void OLog2ToACES
 ( 	input varying float rIn,
	input varying float gIn,
	input varying float bIn,
	input varying float aIn,
	output varying float rOut,
	output varying float gOut,
	output varying float bOut,
	output varying float aOut)
{

float r_lin = normalizedOLog2ToRelativeSceneLinear(rIn);
float g_lin = normalizedOLog2ToRelativeSceneLinear(gIn);
float b_lin = normalizedOLog2ToRelativeSceneLinear(bIn);

float x_D65 = r_lin * 0.6370 + g_lin * 0.1446 + b_lin * 0.1689;
float y_D65 = r_lin * 0.2627 + g_lin * 0.6780 + b_lin * 0.0593;
float z_D65 = r_lin * 0.0 + g_lin * 0.0281 + b_lin * 1.0610;

float x_D60 = x_D65 * 1.01174414 + y_D65 * 0.00770577991 + z_D65 * -0.0157216747;
float y_D60 = x_D65 * 0.00555788933 + y_D65 * 1.00153586 + z_D65 * -0.00626219941;
float z_D60 = x_D65 * -0.000334059457 + y_D65 * -0.00104828776 + z_D65 * 0.927569778;

rOut = x_D60 * 1.0498110175 + y_D60 * 0.0 + z_D60 * -0.0001;
gOut = x_D60 * -0.4959030231 + y_D60 * 1.3733130458 + z_D60 * 0.0982400361;
bOut = x_D60 * 0.0 + y_D60 * 0.0 + z_D60 * 0.9912520182;
aOut = 1.0;

}
