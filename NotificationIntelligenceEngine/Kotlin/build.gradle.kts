plugins {
    kotlin("multiplatform") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
    // Uncomment for Maven Central publishing:
    // `maven-publish`
    // signing
}

group = "com.nie"
version = "1.0.0"

repositories {
    mavenCentral()
}

kotlin {
    // JVM target for server-side and Android
    jvm {
        compilations.all {
            kotlinOptions.jvmTarget = "17"
        }
        testRuns["test"].executionTask.configure {
            useJUnitPlatform()
        }
    }

    // Native targets (optional, can be enabled as needed)
    // iosArm64()
    // iosSimulatorArm64()
    // macosArm64()
    // macosX64()

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.5.0")
            }
        }
        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")
            }
        }
        val jvmMain by getting
        val jvmTest by getting {
            dependencies {
                implementation("org.junit.jupiter:junit-jupiter:5.10.1")
            }
        }
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// ============================================
// Maven Publishing Configuration (Template)
// ============================================
// To publish to Maven Central, uncomment the maven-publish plugin above
// and configure the following:
//
// publishing {
//     publications {
//         withType<MavenPublication> {
//             pom {
//                 name.set("Notification Intelligence Engine")
//                 description.set("Cross-platform library for deterministic event resolution")
//                 url.set("https://github.com/example/notification-intelligence-engine")
//                 licenses {
//                     license {
//                         name.set("MIT License")
//                         url.set("https://opensource.org/licenses/MIT")
//                     }
//                 }
//             }
//         }
//     }
//     repositories {
//         maven {
//             name = "OSSRH"
//             url = uri("https://oss.sonatype.org/service/local/staging/deploy/maven2/")
//             credentials {
//                 username = System.getenv("OSSRH_USERNAME")
//                 password = System.getenv("OSSRH_PASSWORD")
//             }
//         }
//     }
// }
//
// signing {
//     sign(publishing.publications)
// }
