class Vector2D
  constructor: (x=0, y=0) ->
    @x = x
    @y = y

  add: (other) ->
    new Vector2D(@x + other.x, @y + other.y)

  subtract: (other) ->
    new Vector2D(@x - other.x, @y - other.y)

  multiply: (scalar) ->
    new Vector2D(@x * scalar, @y * scalar)

  divide: (scalar) ->
    return new Vector2D(@x / scalar, @y / scalar) if scalar != 0
    new Vector2D(0, 0)

  magnitude: ->
    Math.sqrt(@x * @x + @y * @y)

  normalize: ->
    mag = @magnitude()
    if mag > 0 then @divide(mag) else new Vector2D(0, 0)

  clone: ->
    new Vector2D(@x, @y)

class Collider
  constructor: (entity) ->
    @entity = entity

  checkCollision: (other) ->
    return false unless @entity.position.x < other.entity.position.x + other.size.x and
      @entity.position.x + @entity.size.x > other.entity.position.x and
      @entity.position.y < other.entity.position.y + other.size.y and
      @entity.position.y + @entity.size.y > other.entity.position.y

class PhysicsBody
  constructor: (entity, mass=1, gravity=new Vector2D(0, 0.98)) ->
    @entity = entity
    @mass = mass
    @velocity = new Vector2D(0, 0)
    @acceleration = new Vector2D(0, 0)
    @gravity = gravity
    @isStatic = false

  applyForce: (force=new Vector2D(0, 0)) ->
    return if @isStatic
    accel = force.divide(@mass)
    @acceleration = @acceleration.add(accel)

  update: (delta=1/60) ->
    return if @isStatic
    @applyForce(@gravity)
    @velocity = @velocity.add(@acceleration.multiply(delta))
    @entity.position = @entity.position.add(@velocity.multiply(delta))
    @acceleration = new Vector2D(0, 0)

class Entity
  constructor: (id, position=new Vector2D(), size=new Vector2D(50,50), sprite=null) ->
    @id = id
    @position = position
    @size = size
    @sprite = sprite
    @components = {}
    @collider = null
    @physicsBody = null

  addComponent: (name, component) ->
    @components[name] = component
    if component instanceof Collider then @collider = component
    if component instanceof PhysicsBody then @physicsBody = component

  getComponent: (name) ->
    @components[name]

  update: (delta) ->
    if @physicsBody then @physicsBody.update(delta)

class InputManager
  constructor: ->
    @keysDown = {}

  keyDown: (key) ->
    @keysDown[key] = true

  keyUp: (key) ->
    delete @keysDown[key]

  isKeyDown: (key) ->
    @keysDown[key] ? false

class Renderer
  constructor: (context) ->
    @context = context

  drawEntity: (entity) ->
    if entity.sprite
      @context.drawImage entity.sprite, entity.position.x, entity.position.y, entity.size.x, entity.size.y
    else
      @context.fillStyle = 'black'
      @context.fillRect entity.position.x, entity.position.y, entity.size.x, entity.size.y

  clear: ->
    @context.clearRect 0, 0, @context.canvas.width, @context.canvas.height

class Scene
  constructor: ->
    @entities = []

  addEntity: (entity) ->
    @entities.push(entity)

  removeEntity: (entity) ->
    @entities = @entities.filter (e) -> e.id isnt entity.id

  update: (delta) ->
    for entity in @entities
      entity.update(delta)

  getCollisions: (entity) ->
    collisions = []
    for other in @entities
      continue if other.id is entity.id
      if entity.collider and other.collider and entity.collider.checkCollision(other.collider)
        collisions.push other
    collisions

class GameEngine
  constructor: (canvas) ->
    @canvas = canvas
    @context = canvas.getContext '2d'
    @renderer = new Renderer(@context)
    @scene = new Scene()
    @input = new InputManager()
    @lastTime = null
    @running = false
    @entityIdCounter = 0
    @setupEventListeners()

  setupEventListeners: ->
    window.addEventListener 'keydown', (e) -> @input.keyDown(e.key)
    window.addEventListener 'keyup', (e) -> @input.keyUp(e.key)

  createEntity: (position, size, sprite=null) ->
    entity = new Entity(@entityIdCounter++, position, size, sprite)
    @scene.addEntity(entity)
    entity

  addPhysics: (entity, mass=1) ->
    physics = new PhysicsBody(entity, mass)
    entity.addComponent('physics', physics)
    physics

  addCollider: (entity, width, height) ->
    collider = new Collider(entity)
    entity.addComponent('collider', collider)
    entity.collider

  start: ->
    @running = true
    @loop()

  stop: ->
    @running = false

  loop: (timestamp=0) ->
    if not @lastTime then @lastTime = timestamp
    delta = (timestamp - @lastTime) / 1000
    @lastTime = timestamp
    @update(delta)
    @render()
    if @running then window.requestAnimationFrame(@loop)

  update: (delta) ->
    for entity in @scene.entities
      entity.update(delta)
      if entity.physicsBody
        force = new Vector2D(0, 0)
        if @input.isKeyDown('ArrowLeft') then force.x -= 10
        if @input.isKeyDown('ArrowRight') then force.x += 10
        if @input.isKeyDown('ArrowUp') then force.y -= 10
        entity.physicsBody.applyForce(force)
    for entity in @scene.entities
      collisions = @scene.getCollisions(entity)
      for other in collisions
        if entity.physicsBody and other.physicsBody
          resolveCollision entity, other
    function resolveCollision: (a, b) ->
      overlapX = Math.min(a.position.x + a.size.x - b.position.x, b.position.x + b.size.x - a.position.x)
      overlapY = Math.min(a.position.y + a.size.y - b.position.y, b.position.y + b.size.y - a.position.y)
      if overlapX < overlapY
        if a.position.x < b.position.x
          a.position.x -= overlapX / 2
          b.position.x += overlapX / 2
        else
          a.position.x += overlapX / 2
          b.position.x -= overlapX / 2
        a.physicsBody.velocity.x = 0
        b.physicsBody.velocity.x = 0
      else
        if a.position.y < b.position.y
          a.position.y -= overlapY / 2
          b.position.y += overlapY / 2
        else
          a.position.y += overlapY / 2
          b.position.y -= overlapY / 2
        a.physicsBody.velocity.y = 0
        b.physicsBody.velocity.y = 0

  render: ->
    @renderer.clear()
    for entity in @scene.entities
      @renderer.drawEntity(entity)