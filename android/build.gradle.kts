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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_pcm_sound ships with a stale compileSdkVersion (33) that its own
// transitive deps (androidx.fragment 1.7.1+, androidx.window 1.2.0+) no
// longer support. Force every Android library module up to the app's SDK
// so the build doesn't fail on a plugin we don't control. `:app` is
// excluded: evaluationDependsOn(":app") above already evaluates it before
// this block runs, and afterEvaluate() on an already-evaluated project
// throws.
subprojects {
    if (name == "app") return@subprojects
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
            android.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
