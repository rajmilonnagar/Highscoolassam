
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = "../build"
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.ext.set("android", project.extensions.getByName("android"))
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
