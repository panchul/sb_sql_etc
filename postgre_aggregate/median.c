#include <postgres.h>
#include <fmgr.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

PG_FUNCTION_INFO_V1(median_transfn);

/*
 * Median state transfer function.
 *
 * This function is called for every value in the set that we are calculating
 * the median for. On first call, the aggregate state, if any, needs to be
 * initialized.
 */
// median_transfn(state, val)  
Datum
median_transfn(PG_FUNCTION_ARGS)
{
    MemoryContext agg_context;
    
    Datum *median_data;
    bytea *state = (PG_ARGISNULL(0) ? NULL : PG_GETARG_BYTEA_P(0));
    Datum val_datum = PG_GETARG_DATUM(1);

    if (!AggCheckCallContext(fcinfo, &agg_context))
        elog(ERROR, "median_transfn called in non-aggregate context");

    if (state == NULL)
	{
		// Allocate memory to a new median state array */
		Size arrsize = sizeof(Datum) * 2; // for the prototype, we just use 2 values - n and current_avg

		state = MemoryContextAllocZero(agg_context, VARHDRSZ + arrsize);
		SET_VARSIZE(state, VARHDRSZ + arrsize);
		
		((Datum *) VARDATA(state))[0] = Int32GetDatum(0);
		((Datum *) VARDATA(state))[1] = Int32GetDatum(0);
    }

    median_data = (Datum *) VARDATA(state);
    
    // We should be using two priority_queues, but that might take a lot of memory.
    //
    // Let's keep portion of the samples and count how many of them are outsied of the interval we keep.
    //
    
    // TODO
    
    // DEBUG (wrong answer, but it produces some numbers, I want to see them coming up in psql)
    // As a debug thing to figure out how to write these extensions, let's do the approximation
    // instead, an average value, with just one formula. 
    // new_avg = (prev_avg * n + x)/(n+1)
    //     
    median_data[1] = Int32GetDatum(
                            (DatumGetInt32(median_data[1]) * DatumGetInt32(median_data[0])
                            + DatumGetInt32(val_datum) )
                            / 
                            (DatumGetInt32(median_data[0]) + 1)
                      );
    
    // n++
    median_data[0] = Int32GetDatum(DatumGetInt32(median_data[0]) + 1);
    
    //Doe not worke like this. Which one is the function I could use for tracing without actual debugging?... 
    //elog(DEBUG,"median_dat[0] is now %d", DatumGetInt32(median_data[0]));

    // PG_RETURN_NULL();
    PG_RETURN_BYTEA_P(state);
}

PG_FUNCTION_INFO_V1(median_finalfn);

/*
 * Median final function.
 *
 * This function is called after all values in the median set has been
 * processed by the state transfer function. It should perform any necessary
 * post processing and clean up any temporary state.
 */
// median_finalfn(internal, val INTEGER) => INTEGER
Datum
median_finalfn(PG_FUNCTION_ARGS)
{
    Datum *median_data; // n , median
    bytea *state;
    //Datum val_datum = PG_GETARG_DATUM(1);

    MemoryContext agg_context;

    if (!AggCheckCallContext(fcinfo, &agg_context))
        elog(ERROR, "median_finalfn called in non-aggregate context");

    if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	state = PG_GETARG_BYTEA_P(0);
    median_data = (Datum *) VARDATA(state);

//    PG_RETURN_NULL();
    PG_RETURN_DATUM(median_data[1]); // Int32GetDatum(123)
}

