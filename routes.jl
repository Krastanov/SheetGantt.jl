using Genie.Router

include("render_gantt.jl")

route("/") do
    sheetid = params(:sheetid, "14C4wY1QkQAVYXSD42W87Py2-co9Z16seCunc2B1kTxA")
    column_width = parse(Int, params(:column_width, "28"))
    project_month_span = parse(Int, params(:project_month_span,"37"))
    project_start_date_str = params(:project_start_date_str,"2024-06")
    return render_gantt(sheetid,column_width,project_month_span,project_start_date_str)
end
