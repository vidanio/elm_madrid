module Main where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import StartApp
import Result
import String
import Effects exposing (Effects, Never)
import Json.Decode as JsD exposing ((:=))
import Json.Encode as JsE
import Http
import Task exposing (Task)
import Maybe exposing (Maybe)

-- MODEL

type alias Tema = {
  titulo : String,
  duracion : Int,
  id: Int
}

type alias Model = {
  temas : List Tema,
  tituloInput : String,
  duracionInput : String
}

nuevoTema : String -> Int -> Int -> Tema
nuevoTema titulo duracion id= {
  titulo = titulo,
  duracion = duracion,
  id = id
  }


modeloInicial : Model
modeloInicial = {
  temas = [],
  tituloInput = "",
  duracionInput = ""
  }


init : (Model, Effects Action)
init = (modeloInicial, findAll)


-- EFFECTS

temasDecoder : JsD.Decoder (List Tema)
temasDecoder =
  JsD.list temaDecoder


temaDecoder : JsD.Decoder Tema
temaDecoder =
  JsD.object3 Tema
    ("titulo" := JsD.string)
    ("duracion" := JsD.int)
    ("id" := JsD.int)


temaEncoder : Tema -> String
temaEncoder tema =
  let
      inner =
          JsE.object
            [ ("titulo", JsE.string tema.titulo),
              ("duracion", JsE.int tema.duracion) ]

      namespace : String -> JsE.Value
      namespace name =
        JsE.object [(name, inner)]

  in
      JsE.encode 0 <|
        namespace "tema"


baseUrl : String
baseUrl =
  "http://dock:9009/api/temas"


findAll : Effects Action
findAll =
  Http.get temasDecoder baseUrl
    |> Task.toMaybe
    |> Task.map SetTemas
    |> Effects.task


crearTema : Tema -> Effects Action
crearTema tema =
  let
      body =
        Http.string (temaEncoder tema)

  in
      Http.send Http.defaultSettings
        {
          verb = "POST",
          headers =
            [ ( "Content-Type", "application/json "),
              ( "Accept", "application/json")
            ],
          url = baseUrl,
          body = body
        }
        |> Http.fromJson temaDecoder
        |> Task.toMaybe
        |> Task.map TemaPosted
        |> Effects.task

-- UPDATE


type Action
  = SortByTitulo
  | SortByDuracion
  | Delete Int
  | UpdateTitulo String
  | UpdateDuracion String
  | Nuevo
  | SetTemas (Maybe (List Tema))
  | TemaPosted (Maybe Tema)


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    SortByTitulo ->
      ({ model | temas = List.sortBy .titulo model.temas }, Effects.none)
    SortByDuracion ->
      ({ model | temas = List.sortBy .duracion model.temas }, Effects.none)
    Delete id ->
      ({ model | temas = List.filter (\t -> t.id /= id) model.temas },
      Effects.none)
    UpdateTitulo titulo ->
      ({ model | tituloInput = titulo }, Effects.none)
    UpdateDuracion duracion ->
      case duracion of
        "" -> ({ model | duracionInput = "" }, Effects.none)
        _ ->
          case String.toInt duracion of
            Ok _ -> ({ model | duracionInput = duracion }, Effects.none)
            Err _ -> (model, Effects.none)
    Nuevo ->
      let
          duracion = String.toInt model.duracionInput |> Result.withDefault 0
          tema = nuevoTema model.tituloInput duracion 0
          valido = validateModel model
      in
          case valido of
            True -> 
              (model, crearTema tema)
            False ->
              (model, Effects.none)
    SetTemas response ->
      case response of
        Just temas ->
          ({ model | temas = temas }, Effects.none)
        Nothing ->
          (model, Effects.none)
    TemaPosted response ->
      case response of
        Just tema ->
          ({ model | temas = model.temas ++ [tema] }, Effects.none)
        Nothing ->
          (model, Effects.none)


validateModel : Model -> Bool
validateModel model =
  let
      tituloValido = not (String.isEmpty model.tituloInput)
      duracionValida = case (String.toInt model.duracionInput) of
                         (Err _ ) -> False
                         _        -> True
  in
      tituloValido && duracionValida
  
                         


-- VIEW


totalDuraciones : List Tema -> Int
totalDuraciones temas =
  let
      duraciones = List.map .duracion temas
  in
      List.foldl (+) 0 duraciones

pageHeader : Html
pageHeader =
  h1 [] [text "Temario"]


pageFooter : Html
pageFooter =
  footer []
    [a [href "https://github.com/Batou99/elm_madrid"]
       [text "Generador de temarios"]
    ]


capitulo : Signal.Address Action -> Tema -> Html
capitulo address cap =
  li []
    [ span [class "titulo"] [text cap.titulo],
      span [class "duracion"] [text (toString cap.duracion)],
      button
        [class "delete", onClick address (Delete cap.id)]
        []
    ]


capitulos : Signal.Address Action -> List Tema -> Html
capitulos address temas =
  let
      entradas = List.map (capitulo address) temas 
      elementos = entradas ++ [ muestraTotal (totalDuraciones temas) ]
  in
      ul [] elementos


muestraTotal : Int -> Html
muestraTotal total =
  li
    [class "total"]
    [ span [class "label"] [text "Total"],
      span [class "duracion"] [text (toString total)]
    ]


formularioDeEntrada : Signal.Address Action -> Model -> Html
formularioDeEntrada address model =
  div []
    [ input
      [ type' "text",
        placeholder "Titulo",
        value model.tituloInput,
        name "titulo",
        autofocus True,
        on "input" targetValue (Signal.message address << UpdateTitulo)
        ] [],
      input
      [ type' "text",
        placeholder "Duracion",
        value model.duracionInput,
        name "duracion",
        on "input" targetValue (\str -> Signal.message address (UpdateDuracion str))
        ] [],
      button [ class "add", onClick address Nuevo ] [ text "+" ],
      h2 []
        [ text (model.tituloInput ++ " " ++ model.duracionInput) ]
    ]

 
view : Signal.Address Action -> Model -> Html
view address model =
  div [id "container"]
    [pageHeader, 
    formularioDeEntrada address model,
    capitulos address model.temas,
    button
      [class "sort left", onClick address SortByTitulo]
      [text "Titulo"],
    button
      [class "sort", onClick address SortByDuracion]
      [text "Duracion"],
    pageFooter]


main : Signal Html
main = 
  app.html


app = 
  StartApp.start
    { 
      init = init,
      view = view,
      update = update,
      inputs = []
    }


port tasks : Signal (Task Never ())
port tasks =
  app.tasks
