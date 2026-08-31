allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some Flutter plugins (home_widget 0.9.1) pin jvmTarget 1.8 in their own
    // build.gradle, but depend on libraries shipped as JVM 11 bytecode —
    // Kotlin then refuses to inline them ("Cannot inline bytecode built with
    // JVM target 11 into bytecode that is being built with JVM target 1.8").
    // Force every subproject onto the target the app uses (17); Java and
    // Kotlin must match or AGP's consistency check fails instead.
    // home_widget declares `androidx.glance:glance-appwidget:1.+` — a dynamic
    // range that now resolves to 1.3.0-alpha02, an alpha demanding AGP 9.1 and
    // compileSdk 37. Pin the newest stable release instead. (We render the
    // widget with classic RemoteViews, not Glance, so this is only here to
    // satisfy the plugin's own compilation.)
    configurations.configureEach {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.1")
        }
    }

    // Both halves are required: AGP drives the Java task from the module's
    // `android.compileOptions`, while Kotlin's target is set on the compile
    // task. If they disagree AGP fails with "Inconsistent JVM-target
    // compatibility".
    //
    // This must run in afterEvaluate: a plugins.withId callback fires when
    // com.android.library is *applied*, which is before the plugin's own
    // `android { compileOptions 1.8 }` block runs and overwrites us.
    // Registering afterEvaluate is only legal here because this block sits
    // above the evaluationDependsOn(":app") block, which forces evaluation.
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
