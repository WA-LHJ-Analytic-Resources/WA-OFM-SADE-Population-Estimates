library('shiny')
library('data.table')
library('glue')
library('shinyWidgets')
library('reactlog')
library('shinybusy')
library('glue')
library('readr')
library('DBI')
library('shinythemes')
library('markdown')
library('stringr')

source('utilities.R')
source('fetch_data_localdb.R')
load('raceage.rdata') # load some helpful geography crosswalks

dbpath = file.path(Sys.getenv("OUTPUT_FILEPATH"), 'popdb.duckdb')

# Overwrite the cached age_tab and re_grid in case it got changed by process_data
db = DBI::dbConnect(duckdb::duckdb(), dbpath, read_only = TRUE)

re_grid = dbGetQuery(db, 'select * from re_grid') |> setDT()
re_grid[, race6 := as.character(race6)]
age_tab = dbGetQuery(db, 'select * from age_tab') |> setDT()


# Update possible years
year_list = dbGetQuery(db, 'select distinct year from county order by year')$year

DBI::dbDisconnect(db, shutdown = T)
# zip2cty = merge(zip2cty, cty[, .(target_id = as.character(target_id), county_name = source_name)], by = 'target_id')
# zip2cty[, source_id := as.numeric(source_id)]
# zip2cty = zip2cty[s2t_fraction>.05]
# zip2cty[, source_id := stringr::str_pad(source_id, 5, 'left', 0)]
trt2cty = merge(trt2cty, cty[, .(target_id = as.character(target_id), county_name = source_name)], by = 'target_id')
trt2cty[, source_id := as.numeric(source_id)]
school2cty = merge(school2cty, cty[, .(target_id = as.character(target_id), county_name = source_name)], by = 'target_id')
school2cty = school2cty[s2t_fraction>.05]

setorder(cty, source_id)
setorder(zip2cty, source_id)
setorder(school2cty, source_id)


ma = function(x) div(style="display: inline-block;vertical-align:middle;",x)
make_title = function(title, link = title){
  tags$span(id = link, div(style = "margin-top: .1em; margin-bottom: .1em;font-size: 1.7em;", title))
}
# reactlog_enable()
select_width = '80%'
geog_list = c(
  Block = 'block',
  `Block Group` = 'blockgroup',
  Tract = 'tract',
  State = 'state',
  County = 'county',
  `School District` = 'schooldist',
  `Congressional District` = 'congdist22' #,
  # `Legislative District` = 'legdist24'
  )


age_list = c('All' = 'All', 
             'Single Year' = 'age',
             '6 groups'= 'age_6g',
             '11 groups' = 'age_11g',
             '20 groups' = 'age_20g',
             '5 year age groups' = 'age_5yr') # custom

race_list = c('All' = 'All',
                 'Ethnicity' = 'raceeth2',
                 'Race, 6 groups' = 'race6',
                 'Race/Eth, 7 groups' = 'raceeth7'
                 )



# Define UI
ui <- fluidPage(theme = shinythemes::shinytheme("yeti"),
  # Sticky sidebar per: https://stackoverflow.com/questions/71300472/shiny-how-to-make-titlebarpanel-and-sidebarpanel-sticky-when-mainpanel-is-scro
  tags$style(
    HTML(
      "div.sticky {
  position: -webkit-sticky;
  position: sticky;
  top: 0;
  z-index: 1;
  }"
    )
  ),
  add_busy_spinner(spin = "fading-circle", timeout = 1000, position = 'top-right', 
                   height = '100px', width = '100px', margins = c(20,20)),
  titlePanel("PopPIE v2", 'PopPIE'),
  tabsetPanel(
    id = 'thetabs',
    tabPanel(
      'Select Options',
      sidebarLayout(
        # A sidebar that follows the scroll when a db is loaded
        tagAppendAttributes(
          sidebarPanel(
            width = 2,
            position = 'left',
            uiOutput('pie'),
            hr(),
            htmlOutput('jumps')
          ), class = 'sticky'),
        # main panel
        mainPanel(
          width = 10,
          fluidRow(column(
            10,
            # Selectors
            # Geography
            fluidRow(
              # Geography type
              make_title('Geography', 'Geography'),
              selectInput(
                'geog_type',
                NULL,
                choices = geog_list,
                selected = 'county'
              ),
              uiOutput('county_sub'),
              # Checkbox list of which ones to choose from
              
              uiOutput('geog_select')
                          
            ),
            hr(),
            fluidRow(
              make_title('Year', 'Year'),
              ma(actionButton('year_add', 'Add All Options')),
              ma(actionButton('year_remove', 'Remove All Selections')),
              numericInput('nyears', 'Number of years to combine', value = 1,min = 1, max = 20,step = 1),
              uiOutput('year_select')
            ),
            hr(),

            fluidRow(
              make_title('Age'),
              selectInput(
                'age_type',
                NULL,
                choices = age_list,
                selected = 'All Age'
              ),
              uiOutput('age_select')
            ),
            hr(),
            fluidRow(
              make_title('Race/Ethnicity', 'RacEth'),
              selectInput(
                'race_type',
                label = NULL,
                choices = race_list,
                selected = 'All'
              ),
              uiOutput('race_select')
            ),
            hr(),
            fluidRow(
              make_title('Sex'),
              selectInput('gender_type', label = NULL, choices = c('All', 'By Sex'), selected = 'All'),
              uiOutput('gender_select')
            ),
            hr()
          ))
        )
      )
    ),
    tabPanel('Results',
             sidebarLayout(
               sidebarPanel(
                 width = 2,
                 downloadButton("downloadData", "Download")
               ),
               mainPanel(width = 9,
                         textOutput('limitwarning'),
                         DT::DTOutput('table'))
             ))
  )
)

# Define server logic 
server <- function(input, output, session) {

  result = reactiveVal()
  
  # Connect to supplied data base
  output$downloadData <- downloadHandler(
    filename = 'PopPIE_results.csv',
    content = function(file){
      write.csv(result(), file, row.names = FALSE)
    },
    contentType = 'text/csv'
  )
  
  
  geog = reactiveVal()
  
  output$county_sub = renderUI({
    if(!req(input$geog_type) %in% c('county', 'state')){
      r <- list(
        ma(
            selectInput('county_subset','Subset by county', 
                        choices = c('All', unique(sort(cty$source_name))),selected = 'All')),
        ma(actionButton('geog_add', 'Add All Options')),
        ma(actionButton('geog_remove', 'Remove All Selections'))
      )
    }else{
      # From: https://stackoverflow.com/questions/36709441/how-to-display-widgets-inline-in-shiny
      r<- list(
        ma(actionButton('geog_add', 'Add All Options')),
        ma(actionButton('geog_remove', 'Remove All Selections'))
      )
        
      # r = invisible(NULL)
    }
    
  })
  
  # Update the geographic selection
  # Add
  observeEvent(input$geog_add, {
    req(input$geog_add, geog_choices())
    updateMultiInput(session,
                     inputId = 'geog_select',
                     selected = geog_choices(),
                     choices = geog_choices())
  })
  
  # remove
  observeEvent(input$geog_remove, {
    req(input$geog_remove, geog_choices())
    updateMultiInput(session,
                     inputId = 'geog_select',
                     selected = NULL,
                     choices = geog_choices())
  })
  
  
  
  # check boxes for the relevant geographies
  geog_choices = reactiveVal()
  output$geog_select <- renderUI({
    selection = NULL
    req(input$geog_type)
    if(input$geog_type == 'county'){
      geog(cty)
      chooseme = geog()[, setNames(source_id, source_name)]
    } 
    if(input$geog_type == 'state'){
      geog(data.table(source_id = 53, target_id = 53, source_name = 'Washington State'))
      selection = 53
      chooseme = geog()[, setNames(source_id, source_name)]
    }
    
    if(input$geog_type == 'zip'){
      req(input$county_subset)
      geog(zip2cty)
      chooseme = unique(geog()[, setNames(source_id, source_name)])
      if(input$county_subset != 'All'){
        chooseme = intersect(chooseme, geog()[county_name %in% input$county_subset, source_id])
      } 
    }
    
    if(input$geog_type == 'tract'){
      req(input$county_subset)
      geog(trt2cty)
      chooseme = geog()[, setNames(source_id, source_name)]
      if(input$county_subset != 'All'){
        chooseme = intersect(chooseme, geog()[county_name %in% input$county_subset, source_id])
      } 
    }
    
    lab = names(geog_list)[which(geog_list == input$geog_type)]
    geog_choices(chooseme)
    r = multiInput('geog_select', 
                  label = NULL,
                  choices = chooseme,
                  selected = selection,
                  width = select_width)
      
    
    r
  })

  # Race/ethnicity selections
  race_choices = reactiveVal()
  output$race_select <- renderUI({
    req(input$race_type, input$race_type != 'All')

    race_opts = unique(re_grid[[input$race_type]])
    race_choices(race_opts)
    
    r = list(
      ma(actionButton('race_add', 'Add All Options')),
      ma(actionButton('race_remove', 'Remove All Selections')),
      multiInput('race_select', label = NULL, choices = race_opts,width = select_width)
    )
    r
  })
  
  # Update the race selection
  # Add
  observeEvent(input$race_add, {
    req(input$race_add, race_choices())
    updateMultiInput(session,
                     inputId = 'race_select',
                     selected = race_choices(),
                     choices = race_choices())
  })
  
  # remove
  observeEvent(input$race_remove, {
    req(input$race_remove, race_choices())
    updateMultiInput(session,
                     inputId = 'race_select',
                     selected = NULL,
                     choices = race_choices())
  })
  
  # Age
  age_options = reactiveVal()
  output$age_select <- renderUI({
    req(input$age_type, input$age_type != 'All')

    age_opts = unique(age_tab[[input$age_type]])
    age_options(age_opts)
    r = list(
      ma(actionButton('age_add', 'Add All Options')),
      ma(actionButton('age_remove', 'Remove All Selections')),
      multiInput('age_select', label = NULL, choices = age_opts,width = select_width)
    )

  })
  
  # Update the age selection
  # Add
  observeEvent(input$age_add, {
    req(input$age_add, age_options())
    updateMultiInput(session,
                     inputId = 'age_select',
                     selected = age_options(),
                     choices = age_options())
  })
  
  # remove
  observeEvent(input$age_remove, {
    req(input$age_remove, age_options())
    updateMultiInput(session,
                     inputId = 'age_select',
                     selected = NULL,
                     choices = age_options())
  })
  
  # Year
  year_choices = reactiveVal()
  output$year_select = renderUI({
    y = rev(year_list)
    if(req(input$nyears) > 1){
      
      start_y = y - (input$nyears - 1)
      end_y = y
      
      y = paste0(start_y, ' - ', end_y)
      y = y[start_y %in% year_list]
    } 

    year_choices(y)
    multiInput(
      'year',
      NULL,
      choices = year_choices(),
      selected = year_choices()[1],
      width = select_width
    )
  })

  # Update the year selection
  # Add
  observeEvent(input$year_add, {
    req(input$year_add)
    updateMultiInput(session,
                     inputId = 'year',
                     selected = year_choices(),
                     choices = year_choices())
  })
  
  # remove
  observeEvent(input$year_remove, {
    req(input$year_remove)
    updateMultiInput(session,
                     inputId = 'year',
                     selected = NULL,
                     choices = year_choices())
  })
  
  
  
  output$pie = renderUI({
    # make sure its initialized
    req(input$geog_type, input$age_type, input$race_type, input$gender_type)
    
    
    opts = c(Geography = !is.null(input$geog_select),
             Year = !is.null(input$year),
             Age = !is.null(input$age_select) || input$age_type == 'All',
             Sex = !is.null(input$gender) || input$gender_type == 'All',
             `Race/Eth` = !is.null(input$race_select) || input$race_type == 'All'
             )

    mis = names(opts)[!opts]
    if(any(!opts)){
      txt = paste0('The following options need at least one selection: ', glue_collapse(mis,', '))
      return(renderText(txt))
    }
    
    actionButton('makepie', 'Fetch Results', style="color: #fff; background-color: #6F2DA8; border-color: #2e6da4")
    
  })
  
  output$jumps <- renderText({
    " Jump to Section: 
      <br>
      <a href='#Geography'>Geography</a><br>
      <a href='#Year'>Year</a><br>
      <a href='#Age'>Age</a><br>
      <a href='#RaceEth'>Race/Eth</a><br>
      <a href='#Sex'>Sex</a><br>
    "
    
  })
  
  
  output$gender_select <- renderUI({
    req(input$gender_type, input$gender_type != 'All')
    multiInput(
      'gender',
      NULL,
      choices = c('Male', 'Female'),
      width = select_width
    )
    
    
  })

  output$table <- DT::renderDT({
    # req(result())
    result()

  })

  observeEvent(input$makepie,{
    req(input$makepie)
    updateTabsetPanel(inputId = 'thetabs', selected = 'Results')

  })
  
  # Selected age
  selected_ages = reactiveVal()
  observe({
    req(input$age_type)
    if(input$age_type == 'All'){
      selected_ages('All')
    }else{
      req(input$age_select)
      selected_ages(input$age_select)
    }
  })
  
  #Selected sex
  selected_sex = reactiveVal()
  observe({
    req(input$gender_type)
    if(input$gender_type == 'All'){
      selected_sex('All')
    }else{
      req(input$gender)
      selected_sex(input$gender)
    }
  })
  
  # observe(print(selected_sex()))
  
  # Selected race
  selected_race = reactiveVal()
  observe({
    req(input$race_type)
    if(input$race_type == 'All'){
      selected_race('All')
    }else{
      req(input$race_select)
      selected_race(input$race_select)
    }
  })
  
  
  # # When new estimates are requested
  observeEvent(input$makepie,{
    req(input$makepie, geog())
    groups = list(input$geog_select, input$year, selected_ages(), selected_sex(), selected_race())
    groups = vapply(groups, function(x) !all(x %in% c('53', 'All')), T)
    groups = c('Geography', 'Year' , 'Age', 'Gender', "Race/Eth")[groups]
    
    # if asking for year groups, run multiple queries
    y = input$year
    if(input$nyears > 1){
      y = lapply(y, function(x) trimws(data.table::tstrsplit(x, '-', T)))
      y = lapply(y, function(x) seq(x[1],x[2],1))
      groups = setdiff(groups, 'Year')
    }else{
      y = list(y)
    }

    # Compute the results
    
    pop = lapply(y, function(yy){
      
      p = fetch_pop(
                    dbpath = dbpath,
                    geog_level = input$geog_type, 
                    geog = input$geog_select,
                    year = yy,
                    age_col = input$age_type,
                    age = selected_ages(),
                    gender = selected_sex(),
                    raceeth_col = input$race_type,
                    raceeth = selected_race(),
                    groups = groups
                    )

      if(input$nyears>1) p[, Year := paste0(yy[1],' - ',yy[length(yy)])]
      
      p
      
    })
    pop = rbindlist(pop)
    if(nrow(pop) >0){
      setorder(pop, Geography, Year, Age, Sex, `Race/Eth`)
      pop[, Age := paste0('[', Age, ']')]
      
      pop[, pop := round(pop,2)]
      pop = pop[pop>0]
    }else{
      pop = data.table(`Geography Name` = NA, Geography = NA, Year = NA, Age = NA, Sex = NA, `Race/Eth` = NA, pop = NA)
    }
    # save it to a reactive object
    result(pop)
  })
  
  # if the number of rows is greater than 10000, add a warning
  output$limitwarning = renderText({
    req(result())
    
    if(nrow(result())>=10000){
      return('100,000 rows or more returned. With this number of rows it is not guarenteed all relevant data has been returned. 
             Please try requesting less data and/or contacting rads@kingcounty.gov')
    }else{
      return(invisible(NULL))
    }
    
  })
  
}

# Run the application 
shinyApp(ui = ui, server = server)
