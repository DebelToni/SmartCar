import kotlin.math.*
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

data class Vector2(val x: Double, val y: Double) {
    operator fun plus(other: Vector2) = Vector2(x + other.x, y + other.y)
    operator fun minus(other: Vector2) = Vector2(x - other.x, y - other.y)
    operator fun times(scalar: Double) = Vector2(x * scalar, y * scalar)
    fun length() = sqrt(x * x + y * y)
    fun normalize() = if (length() != 0.0) this * (1.0 / length()) else Vector2(0.0, 0.0)
    fun dot(other: Vector2) = x * other.x + y * other.y
}

interface PhysicsObject {
    var position: Vector2
    var velocity: Vector2
    val mass: Double
    val radius: Double
    fun applyForce(force: Vector2, deltaTime: Double)
    fun update(deltaTime: Double)
}

class Particle(
    override var position: Vector2,
    override var velocity: Vector2,
    override val mass: Double,
    override val radius: Double
) : PhysicsObject {
    private var accumulatedForce = Vector2(0.0, 0.0)

    override fun applyForce(force: Vector2, deltaTime: Double) {
        accumulatedForce += force
    }

    override fun update(deltaTime: Double) {
        val acceleration = accumulatedForce * (1.0 / mass)
        velocity += acceleration * deltaTime
        position += velocity * deltaTime
        accumulatedForce = Vector2(0.0, 0.0)
    }
}

class ForceField(val center: Vector2, val strength: Double, val radius: Double) {
    fun computeForce(point: Vector2): Vector2 {
        val direction = center - point
        val distance = direction.length()
        return if (distance < radius && distance != 0.0) {
            val forceMagnitude = strength * (1 - (distance / radius))
            direction.normalize() * forceMagnitude
        } else {
            Vector2(0.0, 0.0)
        }
    }
}

class CollisionDetector {
    fun detectAndResolve(objects: List<PhysicsObject>) {
        for (i in objects.indices) {
            for (j in i + 1 until objects.size) {
                val objA = objects[i]
                val objB = objects[j]
                val delta = objB.position - objA.position
                val dist = delta.length()
                val minDist = objA.radius + objB.radius
                if (dist < minDist && dist != 0.0) {
                    val overlap = minDist - dist
                    val normal = delta.normalize()
                    resolveCollision(objA, objB, normal, overlap)
                }
            }
        }
    }

    private fun resolveCollision(a: PhysicsObject, b: PhysicsObject, normal: Vector2, penetration: Double) {
        val relativeVelocity = b.velocity - a.velocity
        val velocityAlongNormal = relativeVelocity.dot(normal)
        if (velocityAlongNormal > 0) return
        val restitution = 0.9
        val impulseScalar = -(1 + restitution) * velocityAlongNormal / (1 / a.mass + 1 / b.mass)
        val impulse = normal * impulseScalar
        a.velocity -= impulse * (1 / a.mass)
        b.velocity += impulse * (1 / b.mass)
        val correction = normal * (penetration / (1 / a.mass + 1 / b.mass))
        a.position -= correction * (1 / a.mass)
        b.position += correction * (1 / b.mass)
    }
}

class PhysicsEngine(
    val objects: MutableList<PhysicsObject>,
    val forceFields: List<ForceField>,
    val collisionDetector: CollisionDetector = CollisionDetector()
) {
    private val scope = CoroutineScope(Dispatchers.Default)
    private val running = ConcurrentHashMap.newKeySet<PhysicsObject>()

    fun startSimulation() {
        scope.launch {
            var lastTime = System.nanoTime()
            while (true) {
                val currentTime = System.nanoTime()
                val deltaTime = (currentTime - lastTime) / 1_000_000_000.0
                if (deltaTime > 0.0) {
                    updateObjects(deltaTime)
                    collisionDetector.detectAndResolve(objects)
                }
                lastTime = currentTime
                delay(16L)
            }
        }
    }

    private suspend fun updateObjects(deltaTime: Double) {
        val jobs = objects.map { obj ->
            scope.launch {
                val totalForce = forceFields.fold(Vector2(0.0, 0.0)) { acc, field ->
                    acc + field.computeForce(obj.position)
                }
                obj.applyForce(totalForce, deltaTime)
                obj.update(deltaTime)
            }
        }
        jobs.forEach { it.join() }
    }

    fun addObject(obj: PhysicsObject) {
        objects.add(obj)
    }

    fun removeObject(obj: PhysicsObject) {
        objects.remove(obj)
    }

    fun stopSimulation() {
        scope.cancel()
    }
}

fun main() {
    val particles = mutableListOf<PhysicsObject>()
    val engine = PhysicsEngine(particles, listOf(
        ForceField(Vector2(0.0, 0.0), 50.0, 200.0),
        ForceField(Vector2(300.0, 300.0), -30.0, 150.0)
    ))
    for (i in 1..100) {
        val position = Vector2(Random().nextDouble() * 500, Random().nextDouble() * 500)
        val velocity = Vector2(Random().nextDouble() * 10 - 5, Random().nextDouble() * 10 - 5)
        val particle = Particle(position, velocity, 1.0, 5.0)
        particles.add(particle)
    }
    engine.startSimulation()
    runBlocking {
        delay(10000L)
        engine.stopSimulation()
    }
}