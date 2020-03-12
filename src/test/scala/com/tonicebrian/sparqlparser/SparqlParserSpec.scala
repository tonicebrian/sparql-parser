package com.tonicebrian.sparqlparser

import java.io.File
import java.net.URI
import java.nio.file.Paths
import java.util

import org.antlr.v4.runtime._
import org.eclipse.rdf4j.model.Value
import org.eclipse.rdf4j.model.impl.SimpleValueFactory
import org.eclipse.rdf4j.model.util.{Models, RDFCollections}
import org.eclipse.rdf4j.model.vocabulary.RDF
import org.eclipse.rdf4j.rio.{RDFFormat, Rio}
import org.scalatest.{FlatSpec, Matchers, TryValues}

import scala.jdk.CollectionConverters._
import scala.jdk.OptionConverters._
import scala.util.{Failure, Try}

class SparqlParserSpec extends FlatSpec with Matchers with TryValues {

  "All files tagged as " should "be parsed correctly" in {
    val SUITE_FOLDER = "src/test/resources/sparql11-test-suite/"
    val bufferedReader = io.Source
      .fromFile(s"${SUITE_FOLDER}manifest-all.ttl")
      .bufferedReader()
    val BASE_URI = s"file://" + Paths.get(SUITE_FOLDER).toAbsolutePath + "/"

    val vf = SimpleValueFactory.getInstance()
    val rootManifest = Rio.parse(bufferedReader, BASE_URI, RDFFormat.TRIG)
    val BASE_MF = "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#"

    // Get all the manifests about conformance
    val manifests = List(
      "http://www.w3.org/TR/sparql11-update/",
      "http://www.w3.org/TR/sparql11-query/"
    ).flatMap { testSet =>
      val testSetIRI = vf.createIRI(testSet)
      val testSetResource = Models
        .objectResource(
          rootManifest.filter(
            testSetIRI,
            vf.createIRI(BASE_MF, "conformanceRequirement"),
            null
          )
        )
        .orElse(null)
      RDFCollections
        .asValues(rootManifest, testSetResource, new util.ArrayList[Value]())
        .asScala
        .toList
        .map(_.stringValue())
    }
    // From all manifests extract all files that are about validating syntax
    val POSITIVE_SYNTAX_TEST_IRI =
      "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#PositiveSyntaxTest11"
    val NEGATIVE_SYNTAX_TEST_IRI =
      "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#NegativeSyntaxTest11"
    val parsedSparqlFiles = manifests
      .flatMap { manifest =>
        val uri = new URI(manifest)
        val model = Rio.parse(
          io.Source.fromFile(uri).bufferedReader(),
          s"file://${Paths.get(uri).toAbsolutePath.toString}",
          RDFFormat.TRIG
        )
        List(
          POSITIVE_SYNTAX_TEST_IRI
          // Commenting out Negative Syntax tests since some of them are not related to Syntaxis but Semantics
          // like aggregates/agg12.rq where you need to check which variables are used where
          // , NEGATIVE_SYNTAX_TEST_IRI
        ).map { iriClass =>
          val syntaxTestClass = vf.createIRI(iriClass)
          val sparqlFiles = model
            .filter(null, RDF.TYPE, syntaxTestClass)
            .subjects()
            .asScala
            .flatMap(
              testIRI =>
                Models
                  .getPropertyString(
                    model,
                    testIRI,
                    vf.createIRI(BASE_MF, "action")
                  )
                  .toScala
            )
          (iriClass, sparqlFiles)
        }
      }
      .groupBy(_._1)
      .view
      .mapValues { value =>
        val uris = value.flatMap(_._2)
        uris.map { uri =>
          val fileName = Paths.get(new URI(uri)).toAbsolutePath.toString
          parseSparql(fileName)
        }
      }
      .toMap

    all(parsedSparqlFiles(POSITIVE_SYNTAX_TEST_IRI)) should be a Symbol(
      "success"
    )
    // See comment above
    // all(parsedSparqlFiles(NEGATIVE_SYNTAX_TEST_IRI)) should be a Symbol(
    //   "failure"
    // )
  }

  private def parseSparql(
    fileName: String
  ): Try[SparqlParser.StatementContext] = {
    val fileContents = io.Source.fromFile(fileName).bufferedReader()
    val input = CharStreams.fromReader(fileContents)
    val upper = new CaseChangingCharStream(input, true)
    val lexer = new SparqlLexer(upper)
    lexer.addErrorListener(new BaseErrorListener() {
      override def syntaxError(recognizer: Recognizer[_, _],
                               offendingSymbol: Any,
                               line: Int,
                               charPositionInLine: Int,
                               msg: String,
                               e: RecognitionException): Unit = {
        throw new RuntimeException(e)
      }
    })
    val tokens = new CommonTokenStream(lexer)
    val parser = new SparqlParser(tokens)
    parser.removeErrorListeners()
    parser.addErrorListener(new BaseErrorListener() {
      override def syntaxError(recognizer: Recognizer[_, _],
                               offendingSymbol: Any,
                               line: Int,
                               pos: Int,
                               msg: String,
                               e: RecognitionException): Unit = {
        throw new IllegalStateException(
          "Failed to parse at " + line + "," + pos + ":  " + msg,
          e
        )
      }
    })
    Try(parser.statement()).recoverWith {
      case e: Exception =>
        Failure(
          new IllegalStateException(
            s"Processing file ${fileName} we got: ${e.getMessage}"
          )
        )
    }
  }

}
