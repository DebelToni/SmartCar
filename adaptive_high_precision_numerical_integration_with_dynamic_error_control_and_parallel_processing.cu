with Ada.Text_IO; use Ada.Text_IO;
with Ada.Float_Text_IO; use Ada.Float_Text_IO;
with Ada.Numerics.Float_Elementary_Functions; use Ada.Numerics.Float_Elementary_Functions;

package body Numerical_Integration is

   -- Constants for the integration
   Max_Iterations : constant Integer := 1000;
   Tolerance      : constant Float := 1.0E-6;

   -- Function to integrate: Example: sin(x)
   function Func (X : Float) return Float is
   begin
      return Sin (X);
   end Func;

   -- Adaptive Simpson's rule implementation
   function Adaptive_Simpson (A, B : Float; FA, FB, FM : Float; Epsilon : Float; Depth : Integer) return Float is
      Center : Float := (A + B) / 2.0;
      FL : Float := Func (A);
      FR : Float := Func (B);
      FM_Local : Float := Func (Center);
      S_left, S_right, S_total : Float;
      Error : Float;
      Threshold : Float := Epsilon / 2.0;
   begin
      S_left := ( (A - Center) / 6.0 ) * (FA + 4.0 * FM_Local + Func (A + (Center - A) / 2.0));
      S_right := ( (Center - B) / 6.0 ) * (FM_Local + 4.0 * FB + Func (Center + (B - Center) / 2.0));
      S_total := S_left + S_right;
      Error := Abs (S_total - ( (B - A) / 6.0 ) * (FA + 4.0 * FM_Local + FB));
      if Error < Epsilon or Depth > Max_Iterations then
         return S_total;
      else
         return Adaptive_Simpson (A, Center, FA, FM_Local, Func (A + (Center - A) / 2.0), Epsilon / 2.0, Depth + 1)
               + Adaptive_Simpson (Center, B, FM_Local, FB, Func (Center + (B - Center) / 2.0), Epsilon / 2.0, Depth + 1);
      end if;
   end Adaptive_Simpson;

   -- Main procedure for integration
   procedure Integrate (Lower, Upper : Float; Epsilon : Float; Result : out Float) is
      FA, FB, FM : Float;
   begin
      FA := Func (Lower);
      FB := Func (Upper);
      FM := Func ((Lower + Upper) / 2.0);
      Result := Adaptive_Simpson (Lower, Upper, FA, FB, FM, Epsilon, 0);
   end Integrate;

   -- Parallel processing support (simplified mockup)
   -- Note: Ada supports tasking, but for brevity, this is a placeholder.

   -- Entry point
   procedure Run_Integration is
      Result : Float;
   begin
      -- Example: Integrate sin(x) from 0 to pi
      Integrate (0.0, Float (Pi), Tolerance, Result);
      Put_Line ("Approximate integral of sin(x) from 0 to pi:");
      Put (Result, Fore => 1, Aft => 8);
      New_Line;
   end Run_Integration;

begin
   Run_Integration;
end Numerical_Integration;