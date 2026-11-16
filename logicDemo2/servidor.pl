% Servidor web: Prolog recibe la petición, deduce los datos, pide la imagen a Python
% y la devuelve.
% Uso: swipl servidor.pl            (puerto 8081)
%      swipl servidor.pl 9000

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(aggregate)).
:- use_module(library(apply)).
:- use_module('../logicDemo/consultas').
:- use_module(analisis).

:- initialization(main, main).

:- http_handler(root(.),                  inicio,    []).
:- http_handler(root('grafica/decadas'),  g_decadas, []).
:- http_handler(root('grafica/generos'),  g_generos, []).
:- http_handler(root('grafica/actor'),    g_actor,   []).
:- http_handler(root('grafica/red'),      g_red,     []).
:- http_handler(root(api/base),           api_base,  []).
:- http_handler(root(api/actor),          api_actor, []).

main(Argv) :-
    (   Argv = [A|_], atom_number(A, Puerto) -> true ; Puerto = 8081 ),
    http_server(http_dispatch, [port(Puerto)]),
    format("Demo en http://localhost:~w/~n", [Puerto]),
    thread_get_message(_).

% La página es estática: solo pregunta a las rutas de abajo.
inicio(Peticion) :-
    http_reply_file('web/index.html', [], Peticion).

g_decadas(Peticion) :- grafica_decadas(Archivo), imagen(Archivo, Peticion).
g_generos(Peticion) :- grafica_generos(Archivo), imagen(Archivo, Peticion).

g_actor(Peticion) :-
    http_parameters(Peticion, [nombre(Actor, [])]),
    (   grafica_actor(Actor, Archivo)
    ->  imagen(Archivo, Peticion)
    ;   http_404([], Peticion)
    ).

g_red(Peticion) :-
    http_parameters(Peticion, [nombre(Actor, [])]),
    (   grafica_red(Actor, Archivo)
    ->  imagen(Archivo, Peticion)
    ;   http_404([], Peticion)
    ).

imagen(Archivo, Peticion) :-
    http_reply_file(Archivo, [unsafe(true), cache(false)], Peticion).

% GET /api/base — cifras de toda la base
api_base(_) :-
    aggregate_all(count, pelicula(_, _, _), Peliculas),
    aggregate_all(count, actua(_, _), Creditos),
    reparto_tipico(Media, Mediana),
    reply_json_dict(_{peliculas:Peliculas, creditos:Creditos,
                      reparto_media:Media, reparto_mediana:Mediana}).

% GET /api/actor?nombre=Tom Hanks — carrera (Prolog) y centralidad (networkx)
api_actor(Peticion) :-
    http_parameters(Peticion, [nombre(Actor, [])]),
    (   carrera(Actor, Primer, Ultimo, Cuantas),
        centrales(Actor, 13, Cs)
    ->  companeros(Actor, 12, Ps),
        maplist([N-B, _{actor:B, peliculas:N}]>>true, Ps, Companeros),
        maplist([A-P, _{actor:A, puntaje:P}]>>true, Cs, Centrales),
        reply_json_dict(_{actor:Actor, primer:Primer, ultimo:Ultimo, peliculas:Cuantas,
                          companeros:Companeros, centrales:Centrales})
    ;   reply_json_dict(_{error:"no encontrado"}, [status(404)])
    ).
