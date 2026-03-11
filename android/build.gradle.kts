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

subprojects {
    if (name == "mapbox_maps_flutter") {
        afterEvaluate {
            dependencies.add("implementation", "androidx.lifecycle:lifecycle-common:2.7.0")
            dependencies.add("implementation", "androidx.lifecycle:lifecycle-runtime:2.7.0")
            dependencies.add("implementation", "androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
            configurations.configureEach {
                resolutionStrategy.force(
                    "androidx.lifecycle:lifecycle-common:2.7.0",
                    "androidx.lifecycle:lifecycle-runtime:2.7.0",
                    "androidx.lifecycle:lifecycle-runtime-ktx:2.7.0",
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
