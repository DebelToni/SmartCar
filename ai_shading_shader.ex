defmodule AIBasedShader do
  alias __MODULE__.Utils
  @max_depth 5
  @epsilon 0.001
  @background_color {0.1, 0.1, 0.2}
  @light_intensity 1.5

  def shade(scene, ray, depth \\ 0) do
    with {:hit, hit_info} <- intersect_scene(scene, ray),
         {:material, material} <- get_material(hit_info),
         color <- shade_point(scene, ray, hit_info, material, depth) do
      color
    else
      _ -> @background_color
    end
  end

  defp intersect_scene(scene, ray) do
    Enum.reduce(scene.objects, {:no_hit, nil}, fn obj, acc ->
      case obj.intersect(ray) do
        nil -> acc
        hit when hit.distance < (case acc do {:hit, info} -> info.distance; _ -> :infinity end) ->
          {:hit, %{object: obj, point: hit.point, normal: hit.normal, distance: hit.distance}}
        _ -> acc
      end
    end)
  end

  defp get_material(%{object: object, point: point}) do
    {:ok, object.material}
  end

  defp shade_point(scene, ray, hit_info, material, depth) do
    ambient = Utils.color_scale(material.ambient, material.color)
    diffuse_specular = compute_lighting(scene, hit_info, ray, material)
    reflect_color = compute_reflection(scene, hit_info, ray, material, depth)
    Utils.color_add(ambient, Utils.color_add(diffuse_specular, reflect_color))
  end

  defp compute_lighting(scene, hit_info, ray, material) do
    scene.lights
    |> Enum.reduce({0, 0, 0}, fn light, acc ->
      light_dir = Utils.vector_sub(light.position, hit_info.point) |> Utils.normalize()
      diffuse_intensity = max(Utils.dot(hit_info.normal, light_dir), 0)
      shadow = in_shadow?(scene, hit_info.point, light_dir)
      if shadow do
        acc
      else
        diffuse = Utils.color_scale(diffuse_intensity * light.brightness, material.color)
        reflect_dir = Utils.reflect(Utils.vector_scale(light_dir, -1), hit_info.normal)
        view_dir = Utils.vector_scale(ray.direction, -1)
        spec_angle = max(Utils.dot(reflect_dir, view_dir), 0)
        specular_intensity = :math.pow(spec_angle, material.shininess)
        specular = Utils.color_scale(specular_intensity * light.brightness * @light_intensity, {1,1,1})
        Utils.color_add(acc, Utils.color_add(diffuse, specular))
      end
    end)
  end

  defp in_shadow?(scene, point, light_dir) do
    shadow_ray = %{
      origin: Utils.vector_add(point, Utils.vector_scale(light_dir, @epsilon)),
      direction: light_dir
    }
    case intersect_scene(scene, shadow_ray) do
      {:hit, hit_info} -> hit_info.distance < 1.0
      _ -> false
    end
  end

  defp compute_reflection(scene, hit_info, ray, material, depth) when depth < @max_depth do
    reflect_dir = Utils.reflect(ray.direction, hit_info.normal) |> Utils.normalize()
    reflect_origin = Utils.vector_add(hit_info.point, Utils.vector_scale(reflect_dir, @epsilon))
    reflect_ray = %{origin: reflect_origin, direction: reflect_dir}
    reflect_color = shade(scene, reflect_ray, depth + 1)
    Utils.color_scale(material.reflectivity, reflect_color)
  end

  defp compute_reflection(_, _, _, _, _), do: {0, 0, 0}

  def generate_camera_rays(camera, width, height, fov) do
    aspect_ratio = width / height
    scale = :math.tan(fov * 0.5 * :math.pi / 180)
    for y <- 0..(height - 1),
        x <- 0..(width - 1) do
      px = (2 * ((x + 0.5) / width) - 1) * aspect_ratio * scale
      py = (1 - 2 * ((y + 0.5) / height)) * scale
      dir = Utils.normalize({px, py, -1})
      %{
        origin: camera.position,
        direction: dir
      }
    end
  end

  def render(scene, camera, width, height, fov) do
    rays = generate_camera_rays(camera, width, height, fov)
    Enum.chunk_every(rays, width)
    |> Enum.map(fn row_rays ->
      Enum.map(row_rays, fn ray ->
        shade(scene, ray)
      end)
    end)
  end

  defmodule Utils do
    def color_add({r1, g1, b1}, {r2, g2, b2}) do
      {
        clamp(r1 + r2, 0, 1),
        clamp(g1 + g2, 0, 1),
        clamp(b1 + b2, 0, 1)
      }
    end

    def color_scale(scalar, {r, g, b}) do
      {
        clamp(r * scalar, 0, 1),
        clamp(g * scalar, 0, 1),
        clamp(b * scalar, 0, 1)
      }
    end

    def vector_add({x1, y1, z1}, {x2, y2, z2}) do
      {x1 + x2, y1 + y2, z1 + z2}
    end

    def vector_sub({x1, y1, z1}, {x2, y2, z2}) do
      {x1 - x2, y1 - y2, z1 - z2}
    end

    def vector_scale({x, y, z}, scalar) do
      {x * scalar, y * scalar, z * scalar}
    end

    def dot({x1, y1, z1}, {x2, y2, z2}) do
      x1 * x2 + y1 * y2 + z1 * z2
    end

    def length({x, y, z}) do
      :math.sqrt(x * x + y * y + z * z)
    end

    def normalize(vector) do
      len = length(vector)
      if len == 0 do
        {0, 0, 0}
      else
        vector_scale(vector, 1 / len)
      end
    end

    def reflect(vector, normal) do
      dot_product = dot(vector, normal)
      vector_sub(vector, vector_scale(normal, 2 * dot_product))
    end

    def clamp(value, min, max) do
      cond do
        value < min -> min
        value > max -> max
        true -> value
      end
    end
  end

  defmodule Scene do
    defstruct objects: [], lights: [], camera: nil
  end

  defmodule Object do
    defstruct shape: nil, material: nil

    def intersect(%{shape: shape} = obj, ray) do
      shape.intersect(ray)
    end
  end

  defmodule Sphere do
    defstruct center: {0, 0, 0}, radius: 1.0, material: nil

    def intersect(%{center: c, radius: r} = sphere, %{origin: o, direction: d}) do
      oc = Utils.vector_sub(o, c)
      a = Utils.dot(d, d)
      b = 2 * Utils.dot(oc, d)
      c_val = Utils.dot(oc, oc) - r * r
      discriminant = b * b - 4 * a * c_val
      if discriminant < 0 do
        nil
      else
        sqrt_disc = :math.sqrt(discriminant)
        t1 = (-b - sqrt_disc) / (2 * a)
        t2 = (-b + sqrt_disc) / (2 * a)
        t = if t1 > @epsilon, do: t1, else: t2
        if t < @epsilon do
          nil
        else
          point = Utils.vector_add(o, Utils.vector_scale(d, t))
          normal = Utils.normalize(Utils.vector_sub(point, c))
          %{point: point, normal: normal, distance: t}
        end
      end
    end
  end

  defmodule Plane do
    defstruct point: {0, 0, 0}, normal: {0, 1, 0}, material: nil

    def intersect(%{point: p0, normal: n} = plane, %{origin: o, direction: d}) do
      denom = Utils.dot(n, d)
      if abs(denom) > @epsilon do
        t = Utils.dot(Utils.vector_sub(p0, o), n) / denom
        if t >= @epsilon do
          point = Utils.vector_add(o, Utils.vector_scale(d, t))
          normal = Utils.normalize(n)
          %{point: point, normal: