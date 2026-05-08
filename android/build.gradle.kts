// Required by the hypersdkflutter Gradle plugin — must be set before subproject evaluation
extra["clientId"] = "aivo"
extra["hyperSDKVersion"] = "2.2.2"
extra["excludedMicroSDKs"] = listOf<String>()

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.juspay.in/jp-build-packages/hyper-sdk/") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
