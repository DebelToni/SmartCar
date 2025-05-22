<?php

class GameEngineSubsystem {
    private $entities = [];
    private $components = [];
    private $systems = [];
    private $eventQueue = [];
    private $entityIdCounter = 0;

    public function __construct() {
        $this->registerSystem(new MovementSystem());
        $this->registerSystem(new RenderingSystem());
        $this->registerSystem(new CollisionSystem());
        $this->registerComponent('PositionComponent', PositionComponent::class);
        $this->registerComponent('VelocityComponent', VelocityComponent::class);
        $this->registerComponent('RenderComponent', RenderComponent::class);
        $this->registerComponent('CollisionComponent', CollisionComponent::class);
    }

    public function createEntity($components = []) {
        $entityId = ++$this->entityIdCounter;
        $entity = new Entity($entityId);
        foreach ($components as $name => $component) {
            $entity->addComponent($name, $component);
        }
        $this->entities[$entityId] = $entity;
        return $entity;
    }

    public function addComponent($entityId, $componentName, $componentInstance) {
        if (isset($this->entities[$entityId])) {
            $this->entities[$entityId]->addComponent($componentName, $componentInstance);
        }
    }

    public function removeComponent($entityId, $componentName) {
        if (isset($this->entities[$entityId])) {
            $this->entities[$entityId]->removeComponent($componentName);
        }
    }

    public function registerComponent($name, $class) {
        $this->components[$name] = $class;
    }

    public function getComponent($name) {
        return isset($this->components[$name]) ? $this->components[$name] : null;
    }

    public function registerSystem($system) {
        $this->systems[] = $system;
        $system->setEngine($this);
    }

    public function getEntitiesWithComponents($componentNames) {
        $result = [];
        foreach ($this->entities as $entity) {
            if ($entity->hasComponents($componentNames)) {
                $result[] = $entity;
            }
        }
        return $result;
    }

    public function queueEvent($event) {
        $this->eventQueue[] = $event;
    }

    public function processEvents() {
        foreach ($this->eventQueue as $event) {
            foreach ($this->systems as $system) {
                if (method_exists($system, 'handleEvent')) {
                    $system->handleEvent($event);
                }
            }
        }
        $this->eventQueue = [];
    }

    public function update($deltaTime) {
        foreach ($this->systems as $system) {
            if (method_exists($system, 'update')) {
                $system->update($deltaTime);
            }
        }
        $this->resolveCollisions();
        $this->processEvents();
    }

    private function resolveCollisions() {
        $entities = $this->getEntitiesWithComponents(['CollisionComponent', 'PositionComponent']);
        $count = count($entities);
        for ($i = 0; $i < $count; $i++) {
            for ($j = $i + 1; $j < $count; $j++) {
                $entityA = $entities[$i];
                $entityB = $entities[$j];
                $collisionA = $entityA->getComponent('CollisionComponent');
                $collisionB = $entityB->getComponent('CollisionComponent');
                $posA = $entityA->getComponent('PositionComponent');
                $posB = $entityB->getComponent('PositionComponent');
                if ($this->checkCollision($posA, $collisionA, $posB, $collisionB)) {
                    $this->queueEvent(new CollisionEvent($entityA, $entityB));
                }
            }
        }
    }

    private function checkCollision($posA, $colA, $posB, $colB) {
        $dx = $posA->x - $posB->x;
        $dy = $posA->y - $posB->y;
        $distance = sqrt($dx * $dx + $dy * $dy);
        return $distance < ($colA->radius + $colB->radius);
    }
}

class Entity {
    private $id;
    private $components = [];

    public function __construct($id) {
        $this->id = $id;
    }

    public function addComponent($name, $component) {
        $this->components[$name] = $component;
    }

    public function removeComponent($name) {
        unset($this->components[$name]);
    }

    public function getComponent($name) {
        return isset($this->components[$name]) ? $this->components[$name] : null;
    }

    public function hasComponents($names) {
        foreach ($names as $name) {
            if (!isset($this->components[$name])) {
                return false;
            }
        }
        return true;
    }
}

abstract class System {
    protected $engine;

    public function setEngine($engine) {
        $this->engine = $engine;
    }
}

class MovementSystem extends System {
    public function update($deltaTime) {
        $entities = $this->engine->getEntitiesWithComponents(['PositionComponent', 'VelocityComponent']);
        foreach ($entities as $entity) {
            $pos = $entity->getComponent('PositionComponent');
            $vel = $entity->getComponent('VelocityComponent');
            $pos->x += $vel->vx * $deltaTime;
            $pos->y += $vel->vy * $deltaTime;
        }
    }
}

class RenderingSystem extends System {
    public function update($deltaTime) {
        $entities = $this->engine->getEntitiesWithComponents(['RenderComponent', 'PositionComponent']);
        foreach ($entities as $entity) {
            $pos = $entity->getComponent('PositionComponent');
            $render = $entity->getComponent('RenderComponent');
            $this->renderEntity($render, $pos);
        }
    }

    private function renderEntity($render, $pos) {
        echo "Rendering {$render->sprite} at ({$pos->x}, {$pos->y})\n";
    }
}

class CollisionSystem extends System {
    public function handleEvent($event) {
        if ($event instanceof CollisionEvent) {
            $this->resolveCollision($event->entityA, $event->entityB);
        }
    }

    private function resolveCollision($entityA, $entityB) {
        $velA = $entityA->getComponent('VelocityComponent');
        $velB = $entityB->getComponent('VelocityComponent');
        if ($velA && $velB) {
            $tempVx = $velA->vx;
            $velA->vx = -$velA->vx;
            $velA->vy = -$velA->vy;
            $velB->vx = -$velB->vx;
            $velB->vy = -$velB->vy;
        }
        $this->engine->queueEvent(new SoundEvent('collision'));
    }
}

class PositionComponent {
    public $x;
    public $y;

    public function __construct($x = 0, $y = 0) {
        $this->x = $x;
        $this->y = $y;
    }
}

class VelocityComponent {
    public $vx;
    public $vy;

    public function __construct($vx = 0, $vy = 0) {
        $this->vx = $vx;
        $this->vy = $vy;
    }
}

class RenderComponent {
    public $sprite;

    public function __construct($sprite) {
        $this->sprite = $sprite;
    }
}

class CollisionComponent {
    public $radius;

    public function __construct($radius) {
        $this->radius = $radius;
    }
}

class CollisionEvent {
    public $entityA;
    public $entityB;

    public function __construct($entityA, $entityB) {
        $this->entityA = $entityA;
        $this->entityB = $entityB;
    }
}

class SoundEvent {
    public $soundName;

    public function __construct($soundName) {
        $this->soundName = $soundName;
    }
}

$engine = new GameEngineSubsystem();

$player = $engine->createEntity([
    'PositionComponent' => new PositionComponent(10, 20),
    'VelocityComponent' => new VelocityComponent(1, 0),
    'RenderComponent' => new RenderComponent('player_sprite.png'),
    'CollisionComponent' => new CollisionComponent(5)
]);

$enemy = $engine->createEntity([
    'PositionComponent' => new PositionComponent(50, 20),
    'VelocityComponent' => new VelocityComponent(-1, 0),
    'RenderComponent' => new RenderComponent('enemy_sprite.png'),
    'CollisionComponent' => new CollisionComponent(5)
]);

$projectile = $engine->createEntity([
    'PositionComponent' => new PositionComponent(15, 20),
    'VelocityComponent' => new VelocityComponent(2, 0),
    'RenderComponent' => new RenderComponent('bullet.png'),
    'CollisionComponent' => new CollisionComponent(2)
]);

for ($i = 0; $i < 100; $i