let rand = (~seed) => {
  let x = (seed *. 12.9898) +. 78.233;
  let s = sin(x) *. 43758.5453;
  s -. floor(s)
};

let hash3 = (~p) => {
  let x = p[0] *. 127.1 +. p[1] *. 311.7 +. p[2] *. 74.7;
  let y = p[0] *. 269.5 +. p[1] *. 183.3 +. p[2] *. 246.1;
  let z = p[0] *. 113.7 +. p[1] *. 271.9 +. p[2] *. 124.6;
  [|fract(sin(x) *. 43758.5453), fract(sin(y) *. 43758.5453), fract(sin(z) *. 43758.5453)|]
};

let fade = (t) => t *. t *. t *. (t *. (t *. 6.0 -. 15.0) +. 10.0);

let lerp = (~a, ~b, t) => a +. t *. (b -. a);

let grad = (~hash, ~x, ~y, ~z) => {
  let h = hash land 15;
  let u = if (h < 8) {x} else {y};
  let v = if (h < 4) {y} else if (h == 12 || h == 14) {z} else {x};
  (if ((h land 1) == 0) {u} else {-.u}) +. (if ((h land 2) == 0) {v} else {-.v})
};

let perlinNoise = (~p) => {
  let xi = floor(p[0]);
  let yi = floor(p[1]);
  let zi = floor(p[2]);
  let xf = p[0] -. xi;
  let yf = p[1] -. yi;
  let zf = p[2] -. zi;
  let u = fade(xf);
  let v = fade(yf);
  let w = fade(zf);
  let aaa = hash3(~p=[|xi, yi, zi|]);
  let aba = hash3(~p=[|xi, yi + 1.0, zi|]);
  let aab = hash3(~p=[|xi, yi, zi + 1.0|]);
  let abb = hash3(~p=[|xi, yi + 1.0, zi + 1.0|]);
  let baa = hash3(~p=[|xi + 1.0, yi, zi|]);
  let bba = hash3(~p=[|xi + 1.0, yi + 1.0, zi|]);
  let bab = hash3(~p=[|xi + 1.0, yi, zi + 1.0|]);
  let bbb = hash3(~p=[|xi + 1.0, yi + 1.0, zi + 1.0|]);
  let x1 = lerp(~a=grad(~hash=aaa, ~x=xf, ~y=yf, ~z=zf), ~b=grad(~hash=baa, ~x=xf-.1, ~y=yf, ~z=zf), t=u);
  let x2 = lerp(~a=grad(~hash=aba, ~x=xf, ~y=yf-.1, ~z=zf), ~b=grad(~hash=bba, ~x=xf-.1, ~y=yf-.1, ~z=zf), t=u);
  let y1 = lerp(~a=x1, ~b=x2, t=v);
  let x3 = lerp(~a=grad(~hash=aab, ~x=xf, ~y=yf, ~z=zf-.1), ~b=grad(~hash=bab, ~x=xf-.1, ~y=yf, ~z=zf-.1), t=u);
  let x4 = lerp(~a=grad(~hash=abb, ~x=xf, ~y=yf-.1, ~z=zf-.1), ~b=grad(~hash=bbb, ~x=xf-.1, ~y=yf-.1, ~z=zf-.1), t=u);
  let y2 = lerp(~a=x3, ~b=x4, t=v);
  lerp(~a=y1, ~b=y2, t=w)
};

let fbm = (~p, ~octaves, ~lut) => {
  let rec aux = (~p, ~octaves, ~amp, ~freq, ~sum, ~maxAmp) =>
    if (octaves == 0) {
      sum
    } else {
      let noiseVal = perlinNoise(~p=Array.map((x) => x *. freq, p));
      let value = noiseVal *. amp;
      aux(~p=Array.map((x, i) => x +. 0.5, p), ~octaves=octaves -. 1, ~amp=amp *. 0.5, ~freq=freq *. 2.0, ~sum=sum +. value, ~maxAmp=maxAmp +. amp);
    };
  let result = aux(~p, ~octaves=octaves, ~amp=1.0, ~freq=1.0, ~sum=0.0, ~maxAmp=0.0);
  result /. maxAmp
};

let computeLighting = (~normal, ~lightDir, ~viewDir, ~ambientIntensity, ~diffuseIntensity, ~specularIntensity, ~shininess) => {
  let ndotl = max(0.0, Array.fold_left((acc, x) => acc +. x, 0.0, Array.map2((a, b) => a *. b, normal, lightDir)));
  let reflection = Array.map2((n, l) => 2.0 *. n *. ndotl -. l, normal, lightDir);
  let spec = max(0.0, Array.fold_left((acc, x) => acc +. x, 0.0, Array.map2((a, b) => a *. b, reflection, viewDir)));
  let specular = spec *. specularIntensity;
  (ambientIntensity +. diffuseIntensity *. ndotl +. specular)
};

let getSurfaceColor = (~position, ~normal, ~seed) => {
  let baseColor = [|0.2, 0.4, 0.6|];
  let scale = 4.0;
  let noiseVal = fbm(~p=Array.map((x) => x *. scale, position), ~octaves=5, ~lut=false);
  let colorVariance = [|0.1, 0.1, 0.1|];
  let color = Array.map2((c, v) => c +. v *. noiseVal, baseColor, colorVariance);
  color
};

let mainShader = (~position, ~normal, ~viewDir, ~lightDir, ~seed) => {
  let surfaceColor = getSurfaceColor(~position, ~normal, ~seed);
  let ambient = 0.2;
  let diffuse = 0.7;
  let specular = 0.5;
  let shininess = 32.0;
  let lighting = computeLighting(~normal, ~lightDir, ~viewDir, ~ambient, ~diffuse, ~specular, ~shininess);
  Array.map2((c) => c *. lighting, surfaceColor)
};