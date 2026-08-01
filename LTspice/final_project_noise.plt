[Noise Spectral Density - (V/Hz½ or A/Hz½)]
{
   Npanes: 4
   {
      traces: 1 {524290,0,"V(onoise)*V(onoise)"}
      X: ('G',0,1000,0,1e+10)
      Y[0]: ('p',1,0,3e-13,3.3e-12)
      Y[1]: ('_',0,1e+308,0,-1e+308)
      Units: "V²/Hz" ('p',0,0,1,0,3e-13,3.3e-12)
      Log: 1 0 0
      GridStyle: 1
   },
   {
      traces: 1 {268959747,0,"v(onoise)"}
      X: ('G',0,1000,0,1e+10)
      Y[0]: ('µ',1,0,2e-07,2e-06)
      Y[1]: (' ',0,1e+308,70,-1e+308)
      Units: "V/Hz½" ('µ',0,0,1,0,2e-07,2e-06)
      Log: 1 0 0
      GridStyle: 1
   },
   {
      traces: 1 {524294,0,"V(onoise)/gain"}
      X: ('G',0,1000,0,1e+10)
      Y[0]: ('n',1,5e-10,5e-10,6.5e-09)
      Y[1]: (' ',0,1e+308,70,-1e+308)
      Units: "V/Hz½" ('n',1,1,1,5e-10,5e-10,6.5e-09)
      Log: 1 1 0
      GridStyle: 1
   },
   {
      traces: 1 {524295,0,"v(inoise)"}
      X: ('G',0,1000,0,1e+10)
      Y[0]: ('n',1,5e-10,5e-10,6.5e-09)
      Y[1]: (' ',0,1e+308,70,-1e+308)
      Units: "V/Hz½" ('n',1,1,1,5e-10,5e-10,6.5e-09)
      Log: 1 1 0
      GridStyle: 1
   }
}
