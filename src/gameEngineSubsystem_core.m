#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, EntityState) {
    EntityStateIdle,
    EntityStateMoving,
    EntityStateAttacking,
    EntityStateDamaged
};

@interface Vector3 : NSObject
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat z;
- (instancetype)initWithX:(CGFloat)x y:(CGFloat)y z:(CGFloat)z;
- (Vector3 *)add:(Vector3 *)other;
- (Vector3 *)subtract:(Vector3 *)other;
- (CGFloat)length;
- (Vector3 *)normalize;
@end

@implementation Vector3
- (instancetype)initWithX:(CGFloat)x y:(CGFloat)y z:(CGFloat)z {
    if (self = [super init]) {
        _x = x; _y = y; _z = z;
    }
    return self;
}
- (Vector3 *)add:(Vector3 *)other {
    return [[Vector3 alloc] initWithX:self.x + other.x y:self.y + other.y z:self.z + other.z];
}
- (Vector3 *)subtract:(Vector3 *)other {
    return [[Vector3 alloc] initWithX:self.x - other.x y:self.y - other.y z:self.z - other.z];
}
- (CGFloat)length {
    return sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
}
- (Vector3 *)normalize {
    CGFloat len = [self length];
    if (len == 0) {
        return [[Vector3 alloc] initWithX:0 y:0 z:0];
    }
    return [[Vector3 alloc] initWithX:self.x/len y:self.y/len z:self.z/len];
}
@end

@interface Entity : NSObject
@property (nonatomic, strong) NSString *entityID;
@property (nonatomic, strong) Vector3 *position;
@property (nonatomic, strong) Vector3 *velocity;
@property (nonatomic, assign) EntityState state;
@property (nonatomic, assign) CGFloat health;
@property (nonatomic, assign) BOOL isActive;
- (instancetype)initWithID:(NSString *)entityID position:(Vector3 *)position;
- (void)updateWithDeltaTime:(NSTimeInterval)deltaTime;
- (void)applyForce:(Vector3 *)force;
@end

@implementation Entity
- (instancetype)initWithID:(NSString *)entityID position:(Vector3 *)position {
    if (self = [super init]) {
        _entityID = entityID;
        _position = position;
        _velocity = [[Vector3 alloc] initWithX:0 y:0 z:0];
        _state = EntityStateIdle;
        _health = 100.0;
        _isActive = YES;
    }
    return self;
}
- (void)updateWithDeltaTime:(NSTimeInterval)deltaTime {
    if (!self.isActive) return;
    Vector3 *deltaPosition = [[Vector3 alloc] initWithX:self.velocity.x * deltaTime
                                                      y:self.velocity.y * deltaTime
                                                      z:self.velocity.z * deltaTime];
    self.position = [self.position add:deltaPosition];
}
- (void)applyForce:(Vector3 *)force {
    self.velocity = [self.velocity add:force];
}
@end

@interface PhysicsEngine : NSObject
@property (nonatomic, strong) NSMutableArray<Entity *> *entities;
- (void)addEntity:(Entity *)entity;
- (void)removeEntity:(Entity *)entity;
- (void)simulateWithDeltaTime:(NSTimeInterval)deltaTime;
@end

@implementation PhysicsEngine
- (instancetype)init {
    if (self = [super init]) {
        _entities = [NSMutableArray array];
    }
    return self;
}
- (void)addEntity:(Entity *)entity {
    [self.entities addObject:entity];
}
- (void)removeEntity:(Entity *)entity {
    [self.entities removeObject:entity];
}
- (void)simulateWithDeltaTime:(NSTimeInterval)deltaTime {
    for (Entity *entity in self.entities) {
        [entity updateWithDeltaTime:deltaTime];
        [self.checkCollisionsForEntity:entity];
    }
}
- (void)checkCollisionsForEntity:(Entity *)entity {
    for (Entity *other in self.entities) {
        if (other == entity || !other.isActive) continue;
        CGFloat distance = [entity.position subtract:other.position].length;
        if (distance < 1.0) {
            [self.handleCollisionBetweenEntity:entity andEntity:other];
        }
    }
}
- (void)handleCollisionBetweenEntity:(Entity *)entity andEntity:(Entity *)other {
    entity.health -= 10.0;
    other.health -= 10.0;
    if (entity.health <= 0) {
        entity.isActive = NO;
    }
    if (other.health <= 0) {
        other.isActive = NO;
    }
}
@end

@interface AnimationFrame : NSObject
@property (nonatomic, assign) NSInteger frameID;
@property (nonatomic, strong) NSString *textureName;
@property (nonatomic, assign) NSTimeInterval duration;
@end

@implementation AnimationFrame
@end

@interface AnimationSequence : NSObject
@property (nonatomic, strong) NSArray<AnimationFrame *> *frames;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) NSTimeInterval totalDuration;
- (instancetype)initWithFrames:(NSArray<AnimationFrame *> *)frames loop:(BOOL)loop;
- (AnimationFrame *)currentFrameAtTime:(NSTimeInterval)time;
@end

@implementation AnimationSequence
- (instancetype)initWithFrames:(NSArray<AnimationFrame *> *)frames loop:(BOOL)loop {
    if (self = [super init]) {
        _frames = frames;
        _loop = loop;
        _totalDuration = 0;
        for (AnimationFrame *frame in frames) {
            _totalDuration += frame.duration;
        }
    }
    return self;
}
- (AnimationFrame *)currentFrameAtTime:(NSTimeInterval)time {
    NSTimeInterval t = time;
    if (self.loop) {
        t = fmod(time, self.totalDuration);
    } else if (time >= self.totalDuration) {
        return self.frames.lastObject;
    }
    NSTimeInterval accumulated = 0;
    for (AnimationFrame *frame in self.frames) {
        accumulated += frame.duration;
        if (t <= accumulated) {
            return frame;
        }
    }
    return self.frames.lastObject;
}
@end

@interface Renderer : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *textureCache;
- (void)loadTexture:(NSString *)textureName;
- (void)renderEntity:(Entity *)entity withAnimation:(AnimationSequence *)animation atTime:(NSTimeInterval)time;
@end

@implementation Renderer
- (instancetype)init {
    if (self = [super init]) {
        _textureCache = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)loadTexture:(NSString *)textureName {
    self.textureCache[textureName] = @"LoadedTextureData";
}
- (void)renderEntity:(Entity *)entity withAnimation:(AnimationSequence *)animation atTime:(NSTimeInterval)time {
    AnimationFrame *currentFrame = [animation currentFrameAtTime:time];
    NSString *textureToRender = self.textureCache[currentFrame.textureName];
    if (!textureToRender) {
        [self loadTexture:currentFrame.textureName];
        textureToRender = self.textureCache[currentFrame.textureName];
    }
    NSLog(@"Rendering entity %@ at position (%.2f, %.2f, %.2f) with texture %@", entity.entityID, entity.position.x, entity.position.y, entity.position.z, currentFrame.textureName);
}
@end

@interface GameEngine : NSObject
@property (nonatomic, strong) PhysicsEngine *physicsEngine;
@property (nonatomic, strong) Renderer *renderer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, Entity *> *entities;
@property (nonatomic, strong) NSDictionary<NSString *, AnimationSequence *> *animations;
@property (nonatomic, assign) NSTimeInterval gameTime;
- (void)initializeSubsystems;
- (void)spawnEntityWithID:(NSString *)entityID atPosition:(Vector3 *)position;
- (void)updateWithDeltaTime:(NSTimeInterval)deltaTime;
- (void)renderFrame;
@end

@implementation GameEngine
- (instancetype)init {
    if (self = [super init]) {
        _physicsEngine = [[PhysicsEngine alloc] init];
        _renderer = [[Renderer alloc] init];
        _entities = [NSMutableDictionary dictionary];
        _animations = @{};
        _gameTime = 0;
    }
    return self;
}
- (void)initializeSubsystems {
    // Initialization code for subsystems if needed
}
- (void)spawnEntityWithID:(NSString *)entityID atPosition:(Vector3 *)position {
    Entity *entity = [[Entity alloc] initWithID:entityID position:position];
    [self.physicsEngine addEntity:entity];
    self.entities[entityID] = entity;
}
- (void)updateWithDeltaTime:(NSTimeInterval)deltaTime {
    self.gameTime += deltaTime;
    [self.physicsEngine simulateWithDeltaTime:deltaTime];
    for (Entity *entity in self.entities.allValues) {
        if (entity.isActive) {
            entity.state = EntityStateMoving;
            Vector3 *forwardForce = [[Vector3 alloc] initWithX:0 y:0 z:-1];
            [entity apply