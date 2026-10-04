// ACES IDT for FUJIFILM F-Log2C
// FUFJIFILM Corpration
// Version:1.10


float FLog2ToSceneLinearReflection(float x) {
    if (x > 0.100686685370811)
        return (pow(10,(x - 0.384316) / 0.245281) - 0.064829) / 5.555556;
    else
        return (x - 0.092864) / 8.799461;
}

void main
(   input varying float rIn,
    input varying float gIn,
    input varying float bIn,
    input varying float aIn,
    output varying float rOut,
    output varying float gOut,
    output varying float bOut,
    output varying float aOut)
{

    float r_lin = FLog2ToSceneLinearReflection(rIn);
    float g_lin = FLog2ToSceneLinearReflection(gIn);
    float b_lin = FLog2ToSceneLinearReflection(bIn);

    rOut = r_lin *  0.84089501562825 + g_lin *  0.02752756409115 + b_lin *  0.13157742028060;
    gOut = r_lin *  0.00092026357010 + g_lin *  1.00739011387088 + b_lin * -0.00831037744099;
    bOut = r_lin * -0.00055982840886 + g_lin * -0.00077644453594 + b_lin *  1.00133627294480;
    aOut = 1.0;

}
