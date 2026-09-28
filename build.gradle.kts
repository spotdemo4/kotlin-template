import org.gradle.api.artifacts.dsl.LockMode
import org.gradle.api.tasks.bundling.AbstractArchiveTask

plugins {
    kotlin("jvm") version "2.4.20"
    application
    `maven-publish`
}

group = "zip.trev.template"
version = "0.4.0"

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(25)
}

application {
    mainClass = "MainKt"
}

dependencyLocking {
    lockAllConfigurations()
    lockMode = LockMode.STRICT
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
        }
    }
}

tasks.test {
    useJUnitPlatform()
}

tasks.withType<AbstractArchiveTask>().configureEach {
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}
