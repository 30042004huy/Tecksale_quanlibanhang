import org.gradle.api.Project
import org.gradle.api.file.Directory
import org.gradle.kotlin.dsl.configure
import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // Tự động gán namespace cho các module Android nếu thiếu
    afterEvaluate {
        extensions.findByName("android")?.let {
            configure<BaseExtension> {
                if (namespace == null) {
                    namespace = "com.tecksale.quanlybanhang" // Thay bằng namespace của ứng dụng nếu cần
                }
            }
        }
    }

    // Đảm bảo phụ thuộc vào module :app
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}