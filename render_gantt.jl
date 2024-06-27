using Base64
using Dates
using Downloads

using CSV
using DataFrames
using Mustache
using PrettyPrint

function cat_to_code_s(s::AbstractString, categories)
    i = findfirst(==(s), categories)
    if isnothing(i)
        return 0
    else
        return i
    end
end
cat_to_code(v::AbstractString, categories) = join(sort([cat_to_code_s(strip(s),categories) for s in split(v,",")]),"")
cat_to_code(::Missing, categories) = "0"

function render_gantt(sheetid,column_width,project_month_span,project_start_date_str)
#
# Download the data
#

edit_url = "https://docs.google.com/spreadsheets/d/$(sheetid)/edit"
plans_url = "https://docs.google.com/spreadsheets/d/$(sheetid)/gviz/tq?tqx=out:csv&sheet=Plans"
plans_dl = Downloads.download(plans_url)
plans_csv = CSV.File(plans_dl)
params_url = "https://docs.google.com/spreadsheets/d/$(sheetid)/gviz/tq?tqx=out:csv&sheet=Parameters"
params_dl = Downloads.download(params_url)
params_csv = CSV.File(params_dl)

#
# Extract structured records for the Plans
#

project_start_date = Date(project_start_date_str)
project_start_month = year(project_start_date)*12+month(project_start_date)
project_month(d) = min(max(1,year(d)*12+month(d)-project_start_month+1),project_month_span)
current_month = project_month(today())
categories = vcat([[strip(pp) for pp in split(p, ",")] for p in plans_csv.Category if !ismissing(p) && p!=""]...) |> unique |> sort

plans = []
i = 1
while i<=length(plans_csv)
    r = plans_csv[i]
    if !all(ismissing, r) && !ismissing(r.Plan)
        plan_name = r.Plan
        flagbearer = r.Flagbearer
        target_date = r.Target_Date
        start_date = r.Start_Date
        category = r.Category
        catcode = cat_to_code(category,categories)
        em = project_month(target_date)
        sm = project_month(start_date)
        depends_on = []
        parameters = []
        while true
            ismissing(r.Depends_On) || push!(depends_on, r.Depends_On)
            ismissing(r.Parameter) || push!(parameters, (parameter=r.Parameter,target_value=r.Target_Value,trl=r.TRL))
            i += 1
            i<=length(plans_csv) || break
            r = plans_csv[i]
            ismissing(r.Plan) || break
        end
        plan = (;plan_name,category,catcode,flagbearer,start_date,target_date,depends_on,parameters,
                end_month=em,start_month=sm,target_date_str=Dates.format(target_date, "m/yy"))
        push!(plans,plan)
    else
        i += 1
    end
end

plans_noparams = [p for p in plans if length(p.parameters)==0]

#
# Prepare overall plot
#

#=
parameter_targets = DataFrame([(;param...,target_date=p.target_date) for p in plans for param in p.parameters])
parameters = unique(parameter_targets.parameter)
parameter_targets[!,:value_nounit] = (x->ismissing(x) ? x : parse(Float64,split(x)[1])).(parameter_targets.target_value)

param = parameters[1]

subdf = parameter_targets[parameter_targets.parameter.==param,:]

tick_years = [start_date+Month(i-1) for i in 1:2:project_month_span]
DateTick = Dates.format.(tick_years, "yyyy-mm")

paramplot = @df parameter_targets plot(
    :target_date,
    :value_nounit,
    group=:parameter,
    layout=(length(parameters),1),
    line=false,marker=true,
    size=(600,length(parameters)*200),
    xticks=(tick_years,DateTick),
    xrotation=45,
    bottom_margin=5mm,
    left_margin=10mm,
    xlims=(start_date,start_date+Month(project_month_span)))

tempplot = tempname()*".png"
savefig(paramplot,tempplot)
base64plot = base64encode(read(open(tempplot)))
htmlplot = """<img src="data:image/png;base64,$(base64plot)">"""
=#
htmlplot = "no plot"

#
# Render Gantt chart
#

plan_tpl = """
<section class="plan" id="{{:plan_name}}" data-plan-name="{{:plan_name}}" data-cat="{{:catcode}}" data-start="{{:start_month}}" data-end="{{:end_month}}">
<h2 class="plan_name" >{{:plan_name}}</h2>
{{#:flagbearer}}
<span class="flagbearer">{{:flagbearer}}</span>
{{/:flagbearer}}
<time class="target_date">{{:target_date_str}}</time>
<div class="depends_on">
{{@:depends_on}}
Depends on:
{{/:depends_on}}
{{#:depends_on}}
<span>{{.}}</span>
{{/:depends_on}}
</div>
<div class="parameters">
{{@:parameters}}
Target parameters:
<table>
{{/:parameters}}
{{#:parameters}}
<tr data-parameter="{{:parameter}}"><td>{{:parameter}}</td><td>{{:target_value}}</td><td>{{:trl}}</td></tr>
{{/:parameters}}
{{@:parameters}}
</table>
{{/:parameters}}
</div>
</section>
"""

monthdivs = join(["""<div class="monthbar">$(month(d))<br>$(year(d))</div>""" for d in [project_start_date+Month(i-1) for i in 1:project_month_span]])

plans_tpl = """
<div class="all_plans_container">
<div class="all_plans">
$monthdivs
{{#:plans}}
  {{>:plan_tpl}}
{{/:plans}}
</div>
</div>
"""

gantt_render = render(plans_tpl; plans, plan_tpl)

legend_tpl = """
<section id="gantt_legend">
legend: {{#:categories}}
<span data-cat="{{:catcode}}">{{:category}}</span>
{{/:categories}}
</section>
"""

gantt_legend = render(legend_tpl; categories=[(category=c,catcode=cat_to_code(c,categories)) for c in categories])

#
# Extract structured records for the Parameters
#

params_meta = DataFrame([p for p in params_csv if !isnothing(p.Description)])

params_meta_tpl = """
<div class="all_params_meta">
{{#:params_meta}}
<div class="param_meta" id="{{:Parameter}}">
<h2 class="param_name">{{:Parameter}}</h2>
<p>{{:Description}}</p>
<p>{{:References_Notes}}</p>
{{#:Value_Achieved}}<p>In {{:Experiment_Ref}} they achieved {{:Value_Achieved}} as state of the art.</p>{{/:Value_Achieved}}
<p>It should be easy to achieve {{:Easy_Baseline}}</p>
</div>
{{/:params_meta}}
</div>
"""
params_meta_render = render(params_meta_tpl; params_meta)

#
# Final HTML page
#

tab10colors = ["#4f78a4","#f18e3d","#df595b","#76b6b1","#5aa056","#ecc859","#ae799f","#fe9da7","#9b7461","#b9afab"]
css_for_cat_colors = join(["""[data-cat="$i"]{background-color:$c;}""" for (i,c) in enumerate(tab10colors)])
css_for_cat_colors2 = join(["""[data-cat="$i1$i2"]{background:repeating-linear-gradient(135deg, $c1, $c1 30px, $c2 30px, $c2 60px);}""" for (i1,c1) in enumerate(tab10colors) for (i2,c2) in enumerate(tab10colors)])
css_for_grid_columns = join([""".plan[data-start="$i"] {grid-column-start: $i;}.plan[data-end="$i"]{grid-column-end: $i;}""" for i in 1:project_month_span])

html_tpl = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title></title>
<style>
body {
    font-family: sans;
}
.container {
	max-width: 1200px;
	min-width: 650px;
	margin: 0 auto;
}
.all_plans_container {
    width: 100%;
    overflow-y: auto;
}
.all_plans {
    display: grid;
    position: relative;
    overflow: hidden;
    width: $(project_month_span*column_width)px;
    grid-template-columns: repeat($project_month_span, minmax(0, 1fr));
    gap: 0.1rem;
}
.all_plans > .monthbar {
    border: 1px solid lightgray;
    background-color: lightgray;
    font-size: 0.5rem;
    grid-column: span 1;
    text-align: center;
}
#gantt_legend {
    margin-bottom: 1rem;
}
#gantt_legend > span {
    padding: 0 0.2rem;
    border-radius: 0.2rem;
    color: white;
}
$css_for_grid_columns
$css_for_cat_colors
$css_for_cat_colors2
.plan {
    border: 1px solid lightgray;
    border-radius: 0.4rem;
    padding: 1px;
    transition: opacity;
    transition-duration: 0.5s;
    position: relative;
}
.plan > h2 {
    font-size: 0.8rem;
    color: white;
    margin: 0;
    margin-left: 0.2rem;
    line-height: 1;
}
.plan > .flagbearer {
    font-size: 0.8rem;
    border-radius: 0.4rem;
    background-color: lightgray;
    padding: 0 0.5em 0 0.5em;
}
.plan > .target_date {
    font-size: 0.8rem;
    font-weight: bold;
    float: right;
    color: white;
    padding: 0;
    margin: 0;
}
.plan > .depends_on {
    font-size: 0.6rem;
}
.plan > .depends_on > span {
    border-radius: 0.8rem;
    background-color: lightgray;
    padding: 0 0.5em 0 0.5em;
}
.plan > .parameters {
    position: absolute;
    background-color: lightgray;
    visibility: hidden;
    z-index: 10;
    left: 5rem;
    top: 3rem;
    padding: 0.5rem;
}
.plan:hover > .parameters {
    visibility: visible;
}
.plan > .parameters table {
    border-collapse: collapse;
}
.plan > .parameters td {
    border: 1px solid white;
    padding: 0.2em 1em 0.2em 0.2em;
}
.param_meta {
    display: none;
}
</style>
</head>
<body>
Render a properly structured google sheet into a Gantt chart.
<form method="get">
<div>
<label for="sheetid">google sheet id</label>
<input type="text" name="sheetid" id="sheetid" value="$(sheetid)"/><a href="$(edit_url)">$(edit_url)</a>
</div>
<div>
<label for="column_width">column width</label>
<input type="text" name="column_width" id="column_width" value="$(column_width)"/>
</div>
<div>
<label for="project_month_span">nb of months</label>
<input type="text" name="project_month_span" id="project_month_span" value="$(project_month_span)"/>
</div>
<div>
<label for="project_start_date_str">project start date</label>
<input type="text" name="project_start_date_str" id="project_start_date_str" value="$(project_start_date_str)"/>
</div>
<input type="submit" value="Render">
</form>
<div class="container">
<h1>Timetable Flowchart Gantt-diagram Blame-tableau Pseudo-thingie</h1>
{{{:gantt_legend}}}
<div class="all_plans_container">
{{{:gantt_render}}}
</div>
{{{:params_meta_render}}}
<h1>Log of expected and attained performance parameters</h1>
{{{:htmlplot}}}
</div>
<script>
const allplans = document.querySelectorAll('.plan');
function turngray(plans) {
    for (const p of plans) {
        p.style.opacity = 0.2;
    }
}
function turnsharp(plans) {
    for (const p of plans) {
        p.style.opacity = 1;
    }
}
for (const p of allplans) {
    p.onmouseenter = function (e){
        turngray(allplans);
        turnsharp([p]);
        p.querySelectorAll(".depends_on > span").forEach(x=>turnsharp([document.querySelector(`[data-plan-name="\${x.innerText}"]`)]))
    };
    p.onmouseleave = function (e){
        turnsharp(allplans);
    };
}
const allparamrows = document.querySelectorAll('.parameters table tr');
for (const p of allparamrows) {
    const descr = document.querySelector(`#\${p.dataset.parameter}`);
    if (descr===null) {continue;}
    console.log(descr);
    p.onmouseenter = function (e){
        descr.style.display = "block";
    };
    p.onmouseleave = function (e){
        descr.style.display = "none";
    };
}
</script>
<a href="https://github.com/Krastanov/SheetGantt.jl">Source code for this server available at https://github.com/Krastanov/SheetGantt.jl</a>
</body>
</html>
"""

return render(html_tpl; gantt_render, gantt_legend, params_meta_render, htmlplot)
end
