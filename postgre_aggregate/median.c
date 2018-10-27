#include <postgres.h>
#include <fmgr.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

#define MEDIAN_EXTENSION_MAX_SIZE 100001

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
		// Allocate memory to a new median state array
		Size arrsize = sizeof(Datum) * (MEDIAN_EXTENSION_MAX_SIZE + 1); // [0] - n, the rest is an array

		state = MemoryContextAllocZero(agg_context, VARHDRSZ + arrsize);
		SET_VARSIZE(state, VARHDRSZ + arrsize);
		
		((Datum *) VARDATA(state))[0] = 0;
    }

    median_data = (Datum *) VARDATA(state);
    
    // Presuming memory is not an issue, we should be using two priority_queues, but let's try simple array.
    // In case memory is restricted, we can try keeping portion of the samples and counts how many of them are outside
    // of the interval we keep.
    
    // TODO: !PG_ARGISNULL(1) does not seem to be working as expected
    // e.g. (NULL, 'e') still being counted.
    //
          
    if(MEDIAN_EXTENSION_MAX_SIZE >= median_data[0] && !PG_ARGISNULL(1)) {
    
        median_data[median_data[0] + 1] = val_datum;
    
        // n++
        median_data[0] = median_data[0] + 1;
    }
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
// median_finalfn(internal, val)
Datum
median_finalfn(PG_FUNCTION_ARGS)
{
    Datum *median_data; // n , [array of values]
    bytea *state;
    //Datum val_datum = PG_GETARG_DATUM(1);
    Datum tmp;

    MemoryContext agg_context;

    if (!AggCheckCallContext(fcinfo, &agg_context))
        elog(ERROR, "median_finalfn called in non-aggregate context");

    if (PG_ARGISNULL(0))
		PG_RETURN_NULL();

	state = PG_GETARG_BYTEA_P(0);
    median_data = (Datum *) VARDATA(state);

    // Ineffective bubble sort, but works. Better switch to the existing better one.
    // NOTE: firs element in median_data[] is number of elements
    for(long int i = 1; i < median_data[0]; ++i) {
        for(long int j = i; j < median_data[0]; ++j) {
            if(median_data[j] > median_data[j+1]) {
                tmp = median_data[j];
                median_data[j] = median_data[j+1];
                median_data[j+1] = tmp;
            }
        }
    }
    
    // Maybe deallocate median_data, although, histogram.c implementation does not deallocate
    // anything, so, we seem to not have to too.
    
    PG_RETURN_DATUM(median_data[median_data[0]/2 + 1]);
}

