import Dependencies._

ThisBuild / scalaVersion := "2.13.1"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / organization := "com.tonicebrian"
ThisBuild / organizationName := "sparql-parser"

lazy val root = (project in file("."))
  .enablePlugins(Antlr4Plugin)
  .settings(
    name := "SPARQL parser",
    antlr4Version in Antlr4 := "4.8-1",
    antlr4PackageName in Antlr4 := Some("com.tonicebrian.sparqlparser"),
    libraryDependencies += scalaTest % Test
  )

// See https://www.scala-sbt.org/1.x/docs/Using-Sonatype.html for instructions on how to publish to Sonatype.
