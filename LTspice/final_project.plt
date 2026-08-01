[AC Analysis]
{
   Npanes: 3
   {
      traces: 1 {2,0,"V(out)/(V(inP)-V(inN))"}
      X: ('G',0,1000,0,1e+11)
      Y[0]: (' ',0,0.001,10,1000)
      Y[1]: (' ',0,-330,30,30)
      Log: 1 2 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   },
   {
      traces: 1 {3,0,"V(out1)/(V(inP)-V(inN))"}
      X: ('G',0,1000,0,1e+11)
      Y[0]: (' ',0,0.0562341325190349,5,31.6227766016838)
      Y[1]: (' ',0,-20,20,200)
      Log: 1 2 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   },
   {
      traces: 1 {65540,0,"V(out)/V(out1)"}
      X: ('G',0,1000,0,1e+11)
      Y[0]: (' ',0,0.0158489319246111,6,63.0957344480193)
      Y[1]: (' ',0,60,10,180)
      Log: 1 2 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   }
}
[Transient Analysis]
{
   Npanes: 3
   Active Pane: 1
   {
      traces: 1 {524290,0,"V(vout)/(V(vinp)-V(vinn))"}
      X: (' ',1,0,0.1,1.024)
      Y[0]: ('_',0,-1e+307,1e+307,1e+308)
      Y[1]: (' ',0,1e+308,30,-1e+308)
      Units: "" ('_',0,0,1,-1e+307,1e+307,1e+308)
      Log: 0 0 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   },
   {
      traces: 1 {268959749,0,"V(vout)"}
      X: (' ',1,0,0.1,1.024)
      Y[0]: ('m',0,0,0.09,0.99)
      Y[1]: ('K',2,1e+308,60,-1e+308)
      Volts: ('m',0,0,1,0,0.09,0.99)
      Log: 0 0 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   },
   {
      traces: 1 {524292,0,"V(vout)/V(vinter)"}
      X: (' ',1,0,0.1,1.024)
      Y[0]: (' ',1,0,0.4,4.8)
      Y[1]: (' ',0,1e+308,20,-1e+308)
      Units: "" (' ',0,0,1,0,0.4,4.8)
      Log: 0 0 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   }
}
